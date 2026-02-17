import { ChatMessage, AttachedFile } from '../pages/ChatMessage';
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';
import { pasteboard } from '@kit.BasicServicesKit';
import { HtmlPreviewDialog } from './HtmlPreviewDialog';

@Component
export struct MessageBubble {
  @Prop message: ChatMessage;
  @Prop isStreaming: boolean = false;
  @State htmlPreviewDataUrl: string = '';
  @State reasoningExpanded: boolean = false;
  private markdownController: MarkdownController = new MarkdownController();
  private htmlPreviewDialogController: CustomDialogController = new CustomDialogController({
    builder: HtmlPreviewDialog({
      dataUrl: $htmlPreviewDataUrl
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true
  });

  private registerCodeCopyListener(): void {
    this.markdownController.setCodeCopyListener((text: string) => {
      try {
        const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        systemPasteboard.setData(pasteboardData).catch((err: Error) => {
          console.error('[MessageBubble] setData failed:', err);
        });
      } catch (err) {
        console.error('[MessageBubble] copy listener failed:', err as Error);
      }
    });
  }

  aboutToAppear(): void {
    this.markdownController
      .setTextSize(15)
      .setTextColor('#333333')
      .setTextLineHeight(22)
      .setTitleSize([18, 17, 16, 15, 14, 14])
      .setTitleColor('#1A1A1A')
      .setLatexMathTextSize(14)
      .setCodeBlockBorderRadius(8)
      .setInlineCodeColor('#D63384')
      .setInlineCodeBackgroundColor('#F8F0F4')
      .setInlineCodeBackgroundRadius(4)
      .setQuoteBorderColor('#007AFF')
      .setQuoteBackgroundColor('#F0F5FF')
      .setQuoteBorderRadius(6)
      .setHyperlinkTextColor('#007AFF')
      .setImageBorderRadius(8)
      .setImageMaxWidth('100%');

    this.registerCodeCopyListener();
  }

  private extractHtmlCode(content: string): string {
    const htmlFenceRegex = /```html\s*([\s\S]*?)```/i;
    const htmlFenceMatch = htmlFenceRegex.exec(content);
    if (htmlFenceMatch && htmlFenceMatch[1]) {
      return htmlFenceMatch[1].trim();
    }

    const codeFenceRegex = /```(?:[\w-]+)?\s*([\s\S]*?)```/g;
    let match = codeFenceRegex.exec(content);
    while (match !== null) {
      const code = (match[1] || '').trim();
      const lower = code.toLowerCase();
      if (lower.includes('<!doctype html') || lower.includes('<html') ||
        (lower.includes('<body') && lower.includes('</body>'))) {
        return code;
      }
      match = codeFenceRegex.exec(content);
    }

    return '';
  }

  private hasHtmlPreview(): boolean {
    if (this.message.role !== 'assistant' || this.isStreaming || !this.message.content) {
      return false;
    }
    return this.extractHtmlCode(this.message.content).length > 0;
  }

  private openHtmlPreview(): void {
    if (!this.message.content) {
      return;
    }
    const html = this.extractHtmlCode(this.message.content);
    if (!html) {
      return;
    }
    this.htmlPreviewDataUrl = 'data:text/html;charset=utf-8,' + encodeURIComponent(html);
    this.htmlPreviewDialogController.open();
  }

  private getReasoningContent(): string {
    return (this.message.reasoningContent || '').trim();
  }

  private hasReasoningContent(): boolean {
    return this.getReasoningContent().length > 0;
  }

  private toggleReasoningExpand(): void {
    this.reasoningExpanded = !this.reasoningExpanded;
  }

  build() {
    Column() {
      if (this.message.role === 'user') {
        Column() {
          // Images first (above text bubble)
          if (this.message.images && this.message.images.length > 0) {
            Row() {
              Blank()
              Column({ space: 6 }) {
                ForEach(this.message.images, (img: string, index: number) => {
                  Image('data:image/jpeg;base64,' + img)
                    .width(140)
                    .height(140)
                    .borderRadius(12)
                    .objectFit(ImageFit.Cover)
                    .border({ width: 1, color: 'rgba(0,0,0,0.05)' })
                    .shadow({ radius: 8, color: 'rgba(0,0,0,0.08)', offsetY: 2 })
                }, (img: string, index: number) => 'msg_img_' + index.toString())
              }
            }
            .width('100%')
            .margin({ bottom: 8 })
          }

          // Files (above text bubble)
          if (this.message.files && this.message.files.length > 0) {
            Row() {
              Blank()
              Column({ space: 6 }) {
                ForEach(this.message.files, (file: AttachedFile, index: number) => {
                  Row() {
                    Image($r('app.media.ic_file'))
                      .width(20)
                      .height(20)
                      .fillColor('#007AFF')
                      .margin({ right: 8 })
                    Text(file.name)
                      .fontSize(13)
                      .fontColor('#1A1A1A')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                  }
                  .width(140)
                  .padding(10)
                  .backgroundColor('#F2F2F7')
                  .borderRadius(10)
                  .border({ width: 1, color: '#E5E5EA' })
                }, (file: AttachedFile, index: number) => 'msg_file_' + index.toString())
              }
            }
            .width('100%')
            .margin({ bottom: 8 })
          }

          // Text bubble
          if (this.message.content) {
            Row() {
              Blank()
              Text(this.message.content)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .lineHeight(22)
                .fontWeight(FontWeight.Regular)
                .wordBreak(WordBreak.BREAK_ALL)
                .padding(12)
                .backgroundColor('#3A3A3F')
                .borderRadius(16)
                .constraintSize({ maxWidth: '70%' })
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.10)', offsetY: 2 })
            }
            .width('100%')
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.End)
      } else {
        Column() {
          if (this.hasReasoningContent()) {
            Column() {
              Row() {
                Text(this.reasoningExpanded ? '\u601d\u8003\u8fc7\u7a0b\uff08\u70b9\u51fb\u6536\u8d77\uff09' : '\u601d\u8003\u8fc7\u7a0b\uff08\u70b9\u51fb\u5c55\u5f00\uff09')
                  .fontSize(12)
                  .fontColor('#666666')
                  .fontWeight(FontWeight.Medium)
                Blank()
                Text(this.reasoningExpanded ? '\u6536\u8d77' : '\u5c55\u5f00')
                  .fontSize(11)
                  .fontColor('#8A8A8A')
              }
              .width('100%')
              .onClick(() => {
                this.toggleReasoningExpand();
              })

              if (this.reasoningExpanded) {
                if (this.isStreaming) {
                  Text(this.getReasoningContent())
                    .fontSize(14)
                    .fontColor('#4A4A4A')
                    .lineHeight(20)
                    .wordBreak(WordBreak.BREAK_ALL)
                    .width('100%')
                    .margin({ top: 8 })
                } else {
                  Markdown({
                    text: this.getReasoningContent(),
                    controller: this.markdownController
                  })
                    .width('100%')
                    .margin({ top: 8 })
                }
              }
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor('#F6F6F6')
            .borderRadius(10)
            .margin({ bottom: 8 })
          }

          if (this.isStreaming) {
            if (this.message.content || !this.hasReasoningContent()) {
              Text(this.message.content || '\u601d\u8003\u4e2d...')
                .fontSize(15)
                .fontColor('#333333')
                .lineHeight(22)
                .wordBreak(WordBreak.BREAK_ALL)
                .width('100%')
            }
          } else if (this.message.content) {
            Markdown({
              text: this.message.content,
              controller: this.markdownController
            })
              .width('100%')

            if (this.hasHtmlPreview()) {
              Row() {
                Button('\u9884\u89c8 HTML')
                  .height(30)
                  .fontSize(12)
                  .fontColor('#111111')
                  .backgroundColor('#F2F2F2')
                  .borderRadius(8)
                  .padding({ left: 10, right: 10 })
                  .onClick(() => {
                    this.openHtmlPreview();
                  })
                Blank()
              }
              .width('100%')
              .margin({ top: 8 })
            }
          }
        }
        .width('100%')
        .padding({ left: 4, right: 4, top: 4, bottom: 4 })
      }
    }
    .width('100%')
    .margin({ bottom: 12 })
  }
}
