let storage = new LocalStorage();

/**
 * 桌面卡片：今日课表（2*4 / 4*4）
 *
 * 这里没有用数组绑定 + ForEach，而是用了 6 个固定槽位（s0~s5）。
 * 原因：ArkTS 卡片对 Record<string, Object> 里混装数组的类型推断很挑，
 * 一旦类型对不上，卡片不会报错、只会静默显示空白，排查成本极高。
 * 一天的课最多 6 节封顶完全够用，用扁平字符串槽位换取确定性，是划算的。
 */
@Entry(storage)
@Component
struct TodayCard {
  @LocalStorageProp('dateText') dateText: string = '';
  @LocalStorageProp('weekLabel') weekLabel: string = '';
  @LocalStorageProp('countText') countText: string = '';
  @LocalStorageProp('footerText') footerText: string = '';
  @LocalStorageProp('mode') mode: string = 'today';
  @LocalStorageProp('toggleLabel') toggleLabel: string = '明天';

  @LocalStorageProp('s0Time') s0Time: string = '';
  @LocalStorageProp('s0Name') s0Name: string = '';
  @LocalStorageProp('s0Loc') s0Loc: string = '';
  @LocalStorageProp('s0State') s0State: string = 'none';

  @LocalStorageProp('s1Time') s1Time: string = '';
  @LocalStorageProp('s1Name') s1Name: string = '';
  @LocalStorageProp('s1Loc') s1Loc: string = '';
  @LocalStorageProp('s1State') s1State: string = 'none';

  @LocalStorageProp('s2Time') s2Time: string = '';
  @LocalStorageProp('s2Name') s2Name: string = '';
  @LocalStorageProp('s2Loc') s2Loc: string = '';
  @LocalStorageProp('s2State') s2State: string = 'none';

  @LocalStorageProp('s3Time') s3Time: string = '';
  @LocalStorageProp('s3Name') s3Name: string = '';
  @LocalStorageProp('s3Loc') s3Loc: string = '';
  @LocalStorageProp('s3State') s3State: string = 'none';

  @LocalStorageProp('s4Time') s4Time: string = '';
  @LocalStorageProp('s4Name') s4Name: string = '';
  @LocalStorageProp('s4Loc') s4Loc: string = '';
  @LocalStorageProp('s4State') s4State: string = 'none';

  @LocalStorageProp('s5Time') s5Time: string = '';
  @LocalStorageProp('s5Name') s5Name: string = '';
  @LocalStorageProp('s5Loc') s5Loc: string = '';
  @LocalStorageProp('s5State') s5State: string = 'none';

  /** 一行课 */
  @Builder
  rowOf(time: string, name: string, loc: string, state: string) {
    Row() {
      Text(time)
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
        .width(72)
        .maxLines(1)

      Column() {
        Text(name)
          .fontSize(13)
          .fontWeight(state === 'now' ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(state === 'done' ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (loc.length > 0) {
          Text(loc)
            .fontSize(10)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Text(this.dateText)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)

        // 今天 / 明天 切换。点一下只走 postCardAction，
        // 不用打开 App —— 这是卡片相对于小程序/网页最实在的优势。
        Text(this.toggleLabel)
          .fontSize(10)
          .fontColor('#3D7EFF')
          .backgroundColor('#3D7EFF1A')
          .borderRadius(7)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .margin({ right: 6 })
          .onClick(() => {
            postCardAction(this, {
              action: 'message',
              params: {
                action: 'toggleDay'
              }
            });
          })

        Text(this.weekLabel)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ top: 6, bottom: 2 })

      Column() {
        if (this.s0Name.length > 0) {
          this.rowOf(this.s0Time, this.s0Name, this.s0Loc, this.s0State)
        }
        if (this.s1Name.length > 0) {
          this.rowOf(this.s1Time, this.s1Name, this.s1Loc, this.s1State)
        }
        if (this.s2Name.length > 0) {
          this.rowOf(this.s2Time, this.s2Name, this.s2Loc, this.s2State)
        }
        if (this.s3Name.length > 0) {
          this.rowOf(this.s3Time, this.s3Name, this.s3Loc, this.s3State)
        }
        if (this.s4Name.length > 0) {
          this.rowOf(this.s4Time, this.s4Name, this.s4Loc, this.s4State)
        }
        if (this.s5Name.length > 0) {
          this.rowOf(this.s5Time, this.s5Name, this.s5Loc, this.s5State)
        }
        if (this.s0Name.length === 0) {
          Text('今天没有课，去做点别的吧')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .margin({ top: 12 })
        }
      }
      .width('100%')
      .layoutWeight(1)

      if (this.footerText.length > 0) {
        Text(this.footerText)
          .fontSize(10)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .width('100%')
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {
          page: 'Index'
        }
      });
    })
  }
}
