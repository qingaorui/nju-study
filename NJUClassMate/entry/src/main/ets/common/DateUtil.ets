/**
 * 日期与周次计算工具。
 *
 * 约定：一周从周一算起，weekIndex 从 1 开始；dateKey 统一用 yyyy-MM-dd。
 */
export class DateUtil {
  /** 把 Date 格式化成 yyyy-MM-dd */
  static toDateKey(d: Date): string {
    const y: number = d.getFullYear();
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    return `${y}-${DateUtil.pad2(m)}-${DateUtil.pad2(day)}`;
  }

  /** 把 Date 格式化成 HH:mm */
  static toClock(d: Date): string {
    return `${DateUtil.pad2(d.getHours())}:${DateUtil.pad2(d.getMinutes())}`;
  }

  static pad2(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  /** 解析 yyyy-MM-dd 为当天 00:00 的 Date；解析失败返回 null */
  static parseDateKey(key: string): Date | null {
    if (!key || key.length < 10) {
      return null;
    }
    const parts: string[] = key.split('-');
    if (parts.length !== 3) {
      return null;
    }
    const y: number = Number.parseInt(parts[0], 10);
    const m: number = Number.parseInt(parts[1], 10);
    const d: number = Number.parseInt(parts[2], 10);
    if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d)) {
      return null;
    }
    const date: Date = new Date(y, m - 1, d);
    date.setHours(0, 0, 0, 0);
    return date;
  }

  /** 把 Date 归零到当天 00:00 */
  static startOfDay(d: Date): Date {
    const r: Date = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    r.setHours(0, 0, 0, 0);
    return r;
  }

  /** 把 Date 归零到当天 00:00 后再加上 n 天 */
  static addDays(d: Date, n: number): Date {
    const r: Date = DateUtil.startOfDay(d);
    r.setDate(r.getDate() + n);
    return r;
  }

  /**
   * 返回该日期是星期几：1=周一 ... 7=周日。
   * JS 的 getDay() 里 0=周日，这里换算成中文习惯的 1-7。
   */
  static isoWeekday(d: Date): number {
    const w: number = d.getDay();
    return w === 0 ? 7 : w;
  }

  /** 两个日期相差的整天数（按当地 00:00 计算，避免夏令时误差） */
  static diffDays(from: Date, to: Date): number {
    const a: number = DateUtil.startOfDay(from).getTime();
    const b: number = DateUtil.startOfDay(to).getTime();
    return Math.round((b - a) / 86400000);
  }

  /**
   * 计算某天是学期第几周（第一周记为 1）。
   * 若日期早于开学日，返回 0（尚未开学）。
   */
  static weekIndexOf(semesterStartMonday: string, target: Date): number {
    const start: Date | null = DateUtil.parseDateKey(semesterStartMonday);
    if (start === null) {
      return 0;
    }
    const days: number = DateUtil.diffDays(start, target);
    if (days < 0) {
      return 0;
    }
    return Math.floor(days / 7) + 1;
  }

  /** 把 "HH:mm" 转成"当天第几分钟"，便于比较大小 */
  static clockToMinutes(clock: string): number {
    const parts: string[] = clock.split(':');
    if (parts.length !== 2) {
      return 0;
    }
    const h: number = Number.parseInt(parts[0], 10);
    const m: number = Number.parseInt(parts[1], 10);
    if (Number.isNaN(h) || Number.isNaN(m)) {
      return 0;
    }
    return h * 60 + m;
  }

  /** 把"当天第几分钟"转回 "HH:mm" */
  static minutesToClock(minutes: number): string {
    const safe: number = Math.max(0, Math.floor(minutes));
    return `${DateUtil.pad2(Math.floor(safe / 60) % 24)}:${DateUtil.pad2(safe % 60)}`;
  }

  /** 周几的中文单字，1-7 → 一..日 */
  static weekdayLabel(weekday: number): string {
    const names: string[] = ['', '一', '二', '三', '四', '五', '六', '日'];
    if (weekday < 1 || weekday > 7) {
      return '';
    }
    return names[weekday];
  }

  /** 把"还剩多少分钟"说成人话 */
  static humanizeRemain(minutes: number): string {
    if (minutes < 0) {
      return '已开始';
    }
    if (minutes < 1) {
      return '即将开始';
    }
    if (minutes < 60) {
      return `${minutes} 分钟后`;
    }
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    if (h < 24) {
      return m === 0 ? `${h} 小时后` : `${h} 小时 ${m} 分后`;
    }
    const d: number = Math.floor(h / 24);
    return `${d} 天后`;
  }
}
