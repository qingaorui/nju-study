import { CourseItem, Timetable } from '../model/Course';

/**
 * 一节大课的时间区间
 */
export interface TimeSlot {
  /** 第几节，1 开始 */
  index: number;
  /** 开始时间 HH:mm */
  start: string;
  /** 结束时间 HH:mm */
  end: string;
}

/**
 * 一个可导入的教务站点配置。
 * 结构与 nju.app 的 api/schoolList.json 中单条记录保持一致，
 * 后续想支持东南大学/上交等，只要往 SCHOOL_LIST 里加一条即可。
 */
export interface SchoolProfile {
  /** 唯一 id */
  id: string;
  /** 显示名 */
  title: string;
  /** 一句话说明导入路径，显示给用户看 */
  description: string;
  /** 内置浏览器打开的登录页 */
  initialUrl: string;
  /**
   * 目标页 URL 关键字。当内置浏览器加载的 URL 里包含它时，
   * 说明用户已经登录成功并进到了课表页，此时才注入抓取脚本。
   */
  targetUrlKeyword: string;
  /** 抓取脚本在 rawfile 中的文件名 */
  scriptFile: string;
  /** 点击"导入"前需要执行的预处理脚本（可选，用于自动展开面板） */
  preExtractScript: string;
}

/**
 * 南京大学作息时间表（仙林 / 鼓楼本科教学班次，默认值）。
 *
 * ⚠️ 重要：各校区、各学期作息可能微调（尤其是夏令时/冬令时切换、
 * 研究生课程班次）。这里给的是系统默认值，务必在「设置 → 作息校准」
 * 里对照自己的课表核对一次，否则卡片上的"上课时间"会整体偏移。
 */
export const DEFAULT_TIME_SLOTS: TimeSlot[] = [
  { index: 1, start: '08:00', end: '08:50' },
  { index: 2, start: '09:00', end: '09:50' },
  { index: 3, start: '10:10', end: '11:00' },
  { index: 4, start: '11:10', end: '12:00' },
  { index: 5, start: '13:30', end: '14:20' },
  { index: 6, start: '14:30', end: '15:20' },
  { index: 7, start: '15:40', end: '16:30' },
  { index: 8, start: '16:40', end: '17:30' },
  { index: 9, start: '18:30', end: '19:20' },
  { index: 10, start: '19:30', end: '20:20' },
  { index: 11, start: '20:30', end: '21:20' }
];

/**
 * 南京大学可导入的课表来源。
 * URL 与 nju.app 官方配置（schoolList.json）逐字对齐，改动前请先确认教务系统是否改版。
 */
export const SCHOOL_LIST: SchoolProfile[] = [
  {
    id: 'nju_bks_jw',
    title: '南京大学本科生教务系统',
    description: '通过「我的课表」导入，推荐本科生使用',
    initialUrl:
      'https://authserver.nju.edu.cn/authserver/login?service=https%3A%2F%2Fehallapp.nju.edu.cn%2Fjwapp%2Fsys%2Fwdkb%2F*default%2Findex.do%23%2Fxskcb',
    targetUrlKeyword: 'ehallapp.nju.edu.cn/jwapp/sys/wdkb',
    scriptFile: 'njubksjw.js',
    preExtractScript: ''
  },
  {
    id: 'nju_bks_xk',
    title: '南京大学本科生选课系统',
    description: '通过选课结果导入，适合刚选完课的场景',
    initialUrl: 'https://xk.nju.edu.cn',
    targetUrlKeyword: 'xk.nju.edu.cn/xsxkapp',
    scriptFile: 'njubksxk.js',
    preExtractScript: ''
  },
  {
    id: 'nju_yjs_jw',
    title: '南京大学研究生教务系统',
    description: '研究生请走这个入口（研院有独立的课表界面）',
    initialUrl:
      'https://authserver.nju.edu.cn/authserver/login?service=https%3A%2F%2Fehallapp.nju.edu.cn%2Fgsapp%2Fsys%2Fwdkbapp%2F*default%2Findex.do%23%2Fxskcb',
    targetUrlKeyword: 'ehallapp.nju.edu.cn/gsapp/sys/wdkbapp',
    scriptFile: 'njuyjsjw.js',
    preExtractScript: ''
  },
  {
    id: 'nju_yjs_xk',
    title: '南京大学研究生选课系统',
    description: '研究生同学的另一种导入方式',
    initialUrl: 'https://yjsxk.nju.edu.cn/yjsxkapp/sys/xsxkapp/index_nju.html',
    targetUrlKeyword: 'yjsxk.nju.edu.cn',
    scriptFile: 'njuyjsxk.js',
    preExtractScript: ''
  }
];

/** 教务系统异常时的兜底提示 */
export const VPN_TIP: string =
  '加载失败时请先连接南京大学 VPN（ztna.nju.edu.cn）再试。教务系统偶发抽风，多刷几次通常就好了。';

/** 空课表占位 */
export const EMPTY_TIMETABLE: Timetable = {
  name: '',
  semesterStartMonday: '',
  courses: []
};

/** 生成一条空的课程记录，避免各处重复写字面量 */
export function createEmptyCourse(): CourseItem {
  return {
    name: '',
    classroom: '',
    classNumber: '',
    teacher: '',
    testTime: null,
    testLocation: null,
    info: null,
    weeks: [],
    weekTime: 0,
    startSlot: 0,
    endSlot: 0,
    importType: 1
  };
}
