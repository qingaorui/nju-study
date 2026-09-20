import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { CourseItem, RawCourse, RawScriptResult, Timetable } from '../model/Course';
import { SchoolProfile } from '../constants/SchoolConfig';
import { normalizeCourses } from './CourseStore';
import { Logger } from '../common/Logger';

/** 抓取结果 */
export interface ExtractOutcome {
  ok: boolean;
  /** 失败发生在哪一步，方便定位 */
  stage: string;
  /** 给用户看的提示 */
  message: string;
  /** 解析出的课表，失败时为 null */
  timetable: Timetable | null;
}

/** 脚本回传的原始 JSON 结构 */
interface ScriptEnvelope {
  ok: boolean;
  stage: string;
  message: string;
  data: RawScriptResult | null;
}

/**
 * 原生侧与页面 JS 之间的桥。
 *
 * 页面里的脚本通过 window.njuBridge.postMessage(jsonText) 把结果送出来。
 * 之所以不单纯依赖 runJavaScript 的返回值，是因为：
 *   1. 部分 Web 内核对超长返回值的处理不稳定，课表 JSON 可能几 KB；
 *   2. 以后如果需要"等页面自动翻到某一周再抓"，异步回传是必须的。
 * 两条路都保留：先看桥有没有收到，没收到就退回用返回值。
 */
export class ExtractBridge {
  private received: string = '';

  /** 被 javaScriptProxy 注册进页面的方法，不要改名 */
  postMessage(text: string): void {
    this.received = text;
    Logger.d(`[bridge] 收到脚本回传，长度 ${text.length}`);
  }

  /** 页面侧日志，方便排查教务系统改版 */
  postLog(msg: string): void {
    Logger.i(`[page] ${msg}`);
  }

  reset(): void {
    this.received = '';
  }

  take(): string {
    const t: string = this.received;
    this.received = '';
    return t;
  }
}

/** 全局唯一实例，保证 javaScriptProxy 持有的是同一个对象 */
export const extractBridge: ExtractBridge = new ExtractBridge();

export class Extractor {
  /**
   * 从 rawfile 读取注入脚本。
   * 放在 rawfile 而不是字符串常量里，是为了改脚本时不用重新编译逻辑代码，
   * 也方便直接对照社区脚本 diff。
   */
  static async loadScript(context: common.UIAbilityContext, fileName: string): Promise<string> {
    const bytes: Uint8Array = await context.resourceManager.getRawFileContent(fileName);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  /**
   * 判断当前加载的 URL 是否已经到了课表页。
   * 用关键词匹配而不是全等，因为教务系统会在 URL 后面挂一堆 # 和查询参数。
   */
  static isTargetPage(profile: SchoolProfile, url: string): boolean {
    if (!url) {
      return false;
    }
    return url.indexOf(profile.targetUrlKeyword) >= 0;
  }

  /**
   * 执行抓取。顺序是：
   *   1. 如有预处理脚本，先跑（有些入口需要先点开面板才能看到表格）
   *   2. 跑主抓取脚本
   *   3. 优先取桥回传的结果，否则用 runJavaScript 的返回值
   */
  static async run(
    controller: webview.WebviewController,
    profile: SchoolProfile,
    script: string,
    context: common.UIAbilityContext
  ): Promise<ExtractOutcome> {
    extractBridge.reset();

    if (profile.preExtractScript && profile.preExtractScript.length > 0) {
      try {
        await controller.runJavaScript(profile.preExtractScript);
        // 给页面一点时间响应点击
        await Extractor.sleep(800);
      } catch (e) {
        Logger.w(`预处理脚本执行失败（继续尝试抓取）: ${e}`);
      }
    }

    let returned: string = '';
    try {
      returned = await controller.runJavaScript(script);
      Logger.d(`[extract] runJavaScript 返回长度 ${returned ? returned.length : 0}`);
    } catch (e) {
      Logger.e(`脚本执行异常: ${e}`);
      return {
        ok: false,
        stage: 'execute',
        message: '脚本执行失败，可能是页面还没加载完或已跳转，请回到课表页重试',
        timetable: null
      };
    }

    const fromBridge: string = extractBridge.take();
    const text: string = fromBridge.length > 0 ? fromBridge : returned;
    if (!text || text.length === 0) {
      return {
        ok: false,
        stage: 'empty',
        message: '没有拿到任何数据，请确认页面停留在「我的课表」',
        timetable: null
      };
    }

    return Extractor.parseEnvelope(text, context);
  }

  private static parseEnvelope(text: string, context: common.UIAbilityContext): ExtractOutcome {
    let env: ScriptEnvelope;
    try {
      env = JSON.parse(text) as ScriptEnvelope;
    } catch (e) {
      // 有些渠道回来的是 encodeURIComponent 过的内容（兼容 nju.app 的脚本）
      try {
        env = JSON.parse(decodeURIComponent(text)) as ScriptEnvelope;
      } catch (e2) {
        Logger.e(`回传内容既不是 JSON 也不是 URI 编码 JSON，前 200 字: ${text.substring(0, 200)}`);
        return {
          ok: false,
          stage: 'parseReturn',
          message: '数据格式无法识别，可能是教务系统改版了',
          timetable: null
        };
      }
    }

    if (env.ok === false) {
      return {
        ok: false,
        stage: env.stage ? env.stage : 'unknown',
        message: env.message ? env.message : '抓取失败',
        timetable: null
      };
    }

    if (!env.data || !env.data.courses) {
      // 兼容 nju.app 原始脚本：直接返回 {name, courses}
      const legacy: RawScriptResult = env as RawScriptResult;
      if (legacy.courses) {
        return Extractor.buildTimetable(legacy, context);
      }
      return {
        ok: false,
        stage: 'noData',
        message: '返回内容里没有课程数据',
        timetable: null
      };
    }

    return Extractor.buildTimetable(env.data, context);
  }

  /** 把脚本输出转成内部数据模型 */
  private static buildTimetable(raw: RawScriptResult, context: common.UIAbilityContext): ExtractOutcome {
    const list: CourseItem[] = [];
    for (let i = 0; i < raw.courses.length; i++) {
      const rc: RawCourse = raw.courses[i];
      // 关键换算：脚本里的 time_count 是「末节 - 首节」，这里还原成「末节（含）」
      const startSlot: number = rc.start_time;
      const endSlot: number = rc.time_count > 0 ? startSlot + rc.time_count : startSlot;

      const item: CourseItem = {
        name: rc.name,
        classroom: rc.classroom,
        classNumber: rc.class_number,
        teacher: rc.teacher,
        testTime: rc.test_time,
        testLocation: rc.test_location,
        info: rc.info,
        weeks: rc.weeks,
        weekTime: rc.week_time,
        startSlot: startSlot,
        endSlot: endSlot,
        importType: rc.import_type
      };
      list.push(item);
    }

    const normalized: CourseItem[] = normalizeCourses(list);
    const timetable: Timetable = {
      name: raw.name && raw.name.length > 0 ? raw.name : '当前学期',
      semesterStartMonday: '',
      courses: normalized
    };

    Logger.i(`解析成功：${timetable.name}，${normalized.length} 条课程片段`);
    return {
      ok: true,
      stage: 'done',
      message: `导入成功，共 ${normalized.length} 条课程安排`,
      timetable: timetable
    };
  }

  static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }
}
