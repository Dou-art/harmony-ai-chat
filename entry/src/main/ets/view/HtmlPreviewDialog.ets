import { webview } from '@kit.ArkWeb';

@CustomDialog
export struct HtmlPreviewDialog {
  controller: CustomDialogController;
  @Link dataUrl: string;
  private webController: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Row() {
        Text('HTML 预览')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111111')

        Blank()

        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_close'))
            .width(16)
            .height(16)
            .fillColor('#666666')
        }
        .width(30)
        .height(30)
        .backgroundColor('#F2F2F2')
        .onClick(() => {
          this.controller.close();
        })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .border({ width: { bottom: 1 }, color: '#F0F0F0' })

      Web({
        src: this.dataUrl,
        controller: this.webController
      })
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#FFFFFF')
        .javaScriptAccess(true)
    }
    .width('100%')
    .height('85%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 20, topRight: 20 })
    .clip(true)
  }
}

