import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x9A01;
const TAG: string = 'NJUClassMate';

/** 统一日志出口，方便用 hdc 过滤查看 */
export class Logger {
  static d(msg: string): void {
    hilog.debug(DOMAIN, TAG, '%{public}s', msg);
  }

  static i(msg: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', msg);
  }

  static w(msg: string): void {
    hilog.warn(DOMAIN, TAG, '%{public}s', msg);
  }

  static e(msg: string): void {
    hilog.error(DOMAIN, TAG, '%{public}s', msg);
  }
}
