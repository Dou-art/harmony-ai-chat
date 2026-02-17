@CustomDialog
export struct AttachmentDialog {
  controller: CustomDialogController;
  onImageSelect?: () => void;
  onFileSelect?: () => void;

  build() {
    Column() {
      // Title
      Text('添加附件')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111111')
        .margin({ bottom: 8 })

      Text('选择要发送的内容')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ bottom: 24 })

      // Options
      Column({ space: 12 }) {
        // Image option
        Row() {
          Row({ space: 12 }) {
            Row() {
              Image($r('app.media.ic_image'))
                .width(18)
                .height(18)
                .fillColor('#4A4A4A')
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#EDEDED')
            .borderRadius(10)

            Column({ space: 2 }) {
              Text('图片')
                .fontSize(16)
                .fontColor('#111111')
                .fontWeight(FontWeight.Medium)
              Text('从相册选择图片')
                .fontSize(13)
                .fontColor('#666666')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }

          Blank()

          Image($r('sys.media.ohos_ic_public_arrow_right'))
            .width(16)
            .height(16)
            .fillColor('#888888')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#F5F5F5')
        .borderRadius(12)
        .onClick(() => {
          this.controller.close();
          if (this.onImageSelect) {
            this.onImageSelect();
          }
        })

        // File option
        Row() {
          Row({ space: 12 }) {
            Row() {
              Image($r('app.media.ic_file'))
                .width(18)
                .height(18)
                .fillColor('#4A4A4A')
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#EDEDED')
            .borderRadius(10)

            Column({ space: 2 }) {
              Text('文件')
                .fontSize(16)
                .fontColor('#111111')
                .fontWeight(FontWeight.Medium)
              Text('选择文档或其他文件')
                .fontSize(13)
                .fontColor('#666666')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }

          Blank()

          Image($r('sys.media.ohos_ic_public_arrow_right'))
            .width(16)
            .height(16)
            .fillColor('#888888')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#F5F5F5')
        .borderRadius(12)
        .onClick(() => {
          this.controller.close();
          if (this.onFileSelect) {
            this.onFileSelect();
          }
        })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // Cancel button
      Button('取消')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor('#111111')
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#D8D8D8', radius: 12 })
        .onClick(() => {
          this.controller.close();
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}
