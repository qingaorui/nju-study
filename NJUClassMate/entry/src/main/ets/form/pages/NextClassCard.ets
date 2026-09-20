let storage = new LocalStorage();

/**
 * 桌面卡片：下一节课（2*2 / 2*4）
 *
 * 设计取舍：
 *   - 卡片不设背景色，交给系统画背板，这样浅色/深色模式都自然；
 *   - 文字用 sys.color.* 系统色，跟随系统深浅色自动变化；
 *   - 信息层级：课程名最大，"还有多久"用强调色，地点放最后一行。
 */
@Entry(storage)
@Component
struct NextClassCard {
  @LocalStorageProp('hasClass') hasClass: string = '0';
  @LocalStorageProp('courseName') courseName: string = '还没有课表';
  @LocalStorageProp('timeLine') timeLine: string = '去 App 里一键导入';
  @LocalStorageProp('location') location: string = '';
  @LocalStorageProp('teacher') teacher: string = '';
  @LocalStorageProp('remain') remain: string = '';
  @LocalStorageProp('statusLabel') statusLabel: string = '';
  @LocalStorageProp('weekLabel') weekLabel: string = '';
  @LocalStorageProp('nextHint') nextHint: string = '';
  @LocalStorageProp('accent') accent: string = '#3D7EFF';
  @LocalStorageProp('slotBadge') slotBadge: string = '';

  build() {
    Column() {
      // ---- 顶部：周次 + 状态标签 + 手动刷新 ----
      Row() {
        Text(this.weekLabel)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.statusLabel.length > 0) {
          Text(this.statusLabel)
            .fontSize(10)
            .fontColor(this.accent)
            .backgroundColor(this.accent + '1A')
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }

        // 手动刷新：卡片本身到点会自己刷，但用户改完设置、或觉得数据旧了，
        // 能直接在这里点一下总比先去开 App 再回来舒服。
        Text('刷新')
          .fontSize(10)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({ left: 8, right: 2, top: 2, bottom: 2 })
          .onClick(() => {
            postCardAction(this, {
              action: 'message',
              params: {
                action: 'refresh'
              }
            });
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // ---- 中部：课程名 ----
      Text(this.courseName)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 6 })
        .layoutWeight(1)

      // ---- 底部：时间 / 地点 / 倒计时 ----
      Column() {
        Text(this.timeLine)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row() {
          Text(this.location)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.remain.length > 0) {
            Text(this.remain)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.accent)
          }
        }
        .width('100%')
        .margin({ top: 3 })

        if (this.nextHint.length > 0) {
          Text(this.nextHint)
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 3 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .justifyContent(FlexAlign.SpaceBetween)
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
