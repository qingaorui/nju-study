let storage = new LocalStorage();

/**
 * 锁屏卡片：下一节课（仅 1*2 / 1*1）
 *
 * 锁屏卡片的约束和桌面卡片不同：
 *   - 只能 1*1 或 1*2；
 *   - renderingMode 若配成 singleColor，系统会重绘成单色，
 *     所以这里所有元素都靠"形状 + 文字层级"传达信息，不依赖颜色；
 *   - 空间极小，只保留：课程名 / 时间 / 地点 三要素，倒计时只留最短形式。
 */
@Entry(storage)
@Component
struct LockScreenCard {
  @LocalStorageProp('hasClass') hasClass: string = '0';
  @LocalStorageProp('courseName') courseName: string = '还没有课表';
  @LocalStorageProp('timeLine') timeLine: string = '';
  @LocalStorageProp('location') location: string = '';
  @LocalStorageProp('remain') remain: string = '';
  @LocalStorageProp('statusLabel') statusLabel: string = '';

  build() {
    Column() {
      Text(this.statusLabel.length > 0 ? this.statusLabel : '下一节课')
        .fontSize(10)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .width('100%')

      Text(this.courseName)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 3 })

      Row() {
        Text(this.timeLine)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.remain.length > 0) {
          Text(this.remain)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .margin({ left: 4 })
        }
      }
      .width('100%')
      .margin({ top: 2 })

      if (this.location.length > 0) {
        Text(this.location)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
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
