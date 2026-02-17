import { ChatMessage, AttachedFile } from './ChatMessage';
import { AIService, AIServiceConfig, AIStreamUpdate } from './AIService';
import { APIConfig } from './APIConfig';
import { ConfigManager } from './ConfigManager';
import { SessionManager } from './SessionManager';
import { MessageBubble } from '../view/MessageBubble';
import { ModelSelectorDialog } from '../view/ModelSelectorDialog';
import { AttachmentDialog } from '../view/AttachmentDialog';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';


@Component
export struct ChatPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State currentConfig: APIConfig | null = null;
  @State currentSessionId: string = '';
  @State currentModelName: string = '';
  @State streamingMsgId: string = ''; // Track streaming message
  @State attachedImages: string[] = []; // Base64 encoded images
  @State attachedFiles: AttachedFile[] = [];

  // Model Selector State
  @State allConfigs: APIConfig[] = [];
  @State manualModel: string = '';

  // Watch for session changes from HistoryPage
  @StorageProp('sessionRefresh') @Watch('onSessionRefresh') sessionRefresh: number = 0;
  
  // Watch for config changes from SettingsPage
  @StorageProp('configRefresh') @Watch('onConfigRefresh') configRefresh: number = 0;

  private configManager: ConfigManager = ConfigManager.getInstance();
  private sessionManager: SessionManager = SessionManager.getInstance();
  private scroller: Scroller = new Scroller();
  private streamRenderTimer: number = -1;
  private streamTargetMsgId: string = '';
  private pendingStreamContent: string = '';
  private renderedStreamContent: string = '';
  private pendingStreamReasoningContent: string = '';
  private renderedStreamReasoningContent: string = '';
  private lastFollowScrollTime: number = 0;
  private lastFollowContentLength: number = 0;

  // Model Selector Dialog
  dialogController: CustomDialogController = new CustomDialogController({
    builder: ModelSelectorDialog({
      allConfigs: $allConfigs,
      currentConfigId: this.currentConfig?.id || '',
      currentModel: this.currentModelName,
      manualModel: $manualModel,
      onSelect: (configId: string, model: string) => {
        this.onModelSelected(configId, model);
      }
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: false
  });

  // Attachment Dialog
  attachmentDialogController: CustomDialogController = new CustomDialogController({
    builder: AttachmentDialog({
      onImageSelect: () => {
        this.pickImages();
      },
      onFileSelect: () => {
        this.pickFiles();
      }
    }),
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    autoCancel: true
  });

  onSessionRefresh() {
    if (this.isLoading || this.streamingMsgId !== '') {
      return;
    }
    const currentSession = this.sessionManager.getCurrentSession();
    if (!currentSession) {
      return;
    }
    const localLastContent: string = this.messages.length > 0
      ? this.messages[this.messages.length - 1].content
      : '';
    const remoteLastContent: string = currentSession.messages.length > 0
      ? currentSession.messages[currentSession.messages.length - 1].content
      : '';
    const localLastReasoning: string = this.messages.length > 0
      ? (this.messages[this.messages.length - 1].reasoningContent || '')
      : '';
    const remoteLastReasoning: string = currentSession.messages.length > 0
      ? (currentSession.messages[currentSession.messages.length - 1].reasoningContent || '')
      : '';
    if (currentSession.id === this.currentSessionId &&
      currentSession.messages.length === this.messages.length &&
      localLastContent === remoteLastContent &&
      localLastReasoning === remoteLastReasoning) {
      return;
    }
    this.loadPageData();
  }

  onConfigRefresh() {
    this.loadConfigs();
  }

  async loadConfigs() {
    this.allConfigs = [...this.configManager.getConfigs()];
    const config = this.configManager.getCurrentConfig();
    if (config) {
      this.currentConfig = config;
      this.currentModelName = config.model;
    }
  }

  async aboutToAppear() {
    await this.loadPageData();
  }

  async loadPageData() {
    // Load configs
    this.allConfigs = [...this.configManager.getConfigs()];
    const config = this.configManager.getCurrentConfig();
    if (config) {
      this.currentConfig = config;
      this.currentModelName = config.model;
    } else {
      this.currentConfig = null;
      this.currentModelName = '';
    }
    
    // Load current session
    const currentSession = this.sessionManager.getCurrentSession();
    if (currentSession) {
      this.currentSessionId = currentSession.id;
      this.messages = [...currentSession.messages];
      
      // Scroll to bottom after loading messages
      if (this.messages.length > 0) {
        this.scrollToBottom(100);
      }
    } else {
      this.currentSessionId = '';
      this.messages = [];
    }
  }

  async onModelSelected(configId: string, model: string) {
    // Reload config as it might have changed
    await this.configManager.setCurrentConfig(configId);
    const config = this.configManager.getCurrentConfig();
    if (config) {
      // Update model if changed manually
      if (config.model !== model) {
        config.model = model;
        await this.configManager.updateConfig(config);
      }
      this.currentConfig = config;
      this.currentModelName = model;
      this.allConfigs = [...this.configManager.getConfigs()]; // Refresh list to update selection UI
    }
  }

  startNewSession() {
    this.currentSessionId = '';
    this.messages = [];
    this.inputText = '';
    this.isLoading = false;
    this.attachedImages = [];
    this.attachedFiles = [];
    // Clear current session in SessionManager
    this.sessionManager.setCurrentSession('');
  }

  async pickImages() {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 5;
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoViewPicker.select(photoSelectOptions);
      
      for (let uri of result.photoUris) {
        try {
          const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
          const imageSource = image.createImageSource(file.fd);
          const pixelMap = await imageSource.createPixelMap();
          const imagePackerApi = image.createImagePacker();
          const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 80 };
          const data = await imagePackerApi.packing(pixelMap, packOpts);
          
          // Convert to base64
          const base64 = this.arrayBufferToBase64(data);
          this.attachedImages.push(base64);
          
          fileIo.closeSync(file);
        } catch (err) {
          console.error('[ChatPage] Failed to process image:', err);
        }
      }
    } catch (err) {
      console.error('[ChatPage] Failed to pick images:', err);
    }
  }

  async pickFiles() {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 5;
      const documentViewPicker = new picker.DocumentViewPicker();
      const result = await documentViewPicker.select(documentSelectOptions);
      
      for (let uri of result) {
        try {
          const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
          const stat = fileIo.statSync(file.fd);
          const buffer = new ArrayBuffer(stat.size);
          fileIo.readSync(file.fd, buffer);
          
          const fileName = uri.substring(uri.lastIndexOf('/') + 1);
          const base64Content = this.arrayBufferToBase64(buffer);
          
          this.attachedFiles.push({
            name: fileName,
            size: stat.size,
            type: this.getFileType(fileName),
            content: base64Content
          });
          
          fileIo.closeSync(file);
        } catch (err) {
          console.error('[ChatPage] Failed to process file:', err);
        }
      }
    } catch (err) {
      console.error('[ChatPage] Failed to pick files:', err);
    }
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    const base64Str = this.buffer2String(bytes);
    return base64Str;
  }

  private buffer2String(buffer: Uint8Array): string {
    let result = '';
    const len = buffer.length;
    for (let i = 0; i < len; i++) {
      result += String.fromCharCode(buffer[i]);
    }
    // Simple base64 encoding
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let base64 = '';
    for (let i = 0; i < result.length; i += 3) {
      const byte1 = result.charCodeAt(i);
      const byte2 = i + 1 < result.length ? result.charCodeAt(i + 1) : 0;
      const byte3 = i + 2 < result.length ? result.charCodeAt(i + 2) : 0;
      
      const enc1 = byte1 >> 2;
      const enc2 = ((byte1 & 3) << 4) | (byte2 >> 4);
      const enc3 = ((byte2 & 15) << 2) | (byte3 >> 6);
      const enc4 = byte3 & 63;
      
      base64 += chars.charAt(enc1) + chars.charAt(enc2);
      base64 += (i + 1 < result.length) ? chars.charAt(enc3) : '=';
      base64 += (i + 2 < result.length) ? chars.charAt(enc4) : '=';
    }
    return base64;
  }

  private getFileType(fileName: string): string {
    const ext = fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase();
    const typeMap: Record<string, string> = {
      'txt': 'text/plain',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'json': 'application/json',
      'xml': 'application/xml'
    };
    return typeMap[ext] || 'application/octet-stream';
  }

  removeImage(index: number): void {
    this.attachedImages.splice(index, 1);
    this.attachedImages = Array.from(this.attachedImages);
  }

  removeFile(index: number): void {
    this.attachedFiles.splice(index, 1);
    this.attachedFiles = Array.from(this.attachedFiles);
  }

  canSendMessage(): boolean {
    return !this.isLoading && 
           this.currentConfig !== null && 
           (this.inputText.trim() !== '' || 
            this.attachedImages.length > 0 || 
            this.attachedFiles.length > 0);
  }

  private applyStreamingContent(messageId: string, content: string, reasoningContent: string): void {
    const index = this.messages.findIndex((m: ChatMessage) => m.id === messageId);
    if (index === -1) {
      return;
    }
    const currentMessage = this.messages[index];
    const currentReasoning = currentMessage.reasoningContent || '';
    if (currentMessage.content === content && currentReasoning === reasoningContent) {
      return;
    }

    const updatedMessage: ChatMessage = {
      id: currentMessage.id,
      role: currentMessage.role,
      content: content,
      reasoningContent: reasoningContent || undefined,
      timestamp: Date.now(),
      images: currentMessage.images ? Array.from(currentMessage.images) : undefined,
      files: currentMessage.files ? Array.from(currentMessage.files) : undefined
    };
    const newMessages = [...this.messages];
    newMessages[index] = updatedMessage;
    this.messages = newMessages;
  }

  private followStreaming(force: boolean = false): void {
    const now = Date.now();
    if (!force && now - this.lastFollowScrollTime < 120) {
      return;
    }
    this.lastFollowScrollTime = now;
    this.scrollToBottom(0);
  }

  private nextRenderedLength(currentLength: number, targetLength: number): number {
    if (targetLength <= currentLength) {
      return currentLength;
    }
    const backlog: number = targetLength - currentLength;
    const step: number = Math.min(12, Math.max(2, Math.ceil(backlog / 16)));
    return Math.min(targetLength, currentLength + step);
  }

  private renderStreamingFrame(forceFollow: boolean = false): void {
    if (!this.streamTargetMsgId) {
      return;
    }
    const currentAnswerLength: number = this.renderedStreamContent.length;
    const targetAnswerLength: number = this.pendingStreamContent.length;
    const currentReasoningLength: number = this.renderedStreamReasoningContent.length;
    const targetReasoningLength: number = this.pendingStreamReasoningContent.length;

    if (targetAnswerLength <= currentAnswerLength &&
      targetReasoningLength <= currentReasoningLength) {
      if (forceFollow && (targetAnswerLength > 0 || targetReasoningLength > 0)) {
        this.followStreaming(true);
      }
      return;
    }

    const nextAnswerLength = this.nextRenderedLength(currentAnswerLength, targetAnswerLength);
    const nextReasoningLength = this.nextRenderedLength(currentReasoningLength, targetReasoningLength);
    this.renderedStreamContent = this.pendingStreamContent.substring(0, nextAnswerLength);
    this.renderedStreamReasoningContent = this.pendingStreamReasoningContent.substring(0, nextReasoningLength);
    this.applyStreamingContent(
      this.streamTargetMsgId,
      this.renderedStreamContent,
      this.renderedStreamReasoningContent
    );

    const nextProgress = nextAnswerLength + nextReasoningLength;
    if (forceFollow || nextProgress - this.lastFollowContentLength >= 8) {
      this.lastFollowContentLength = nextProgress;
      this.followStreaming(forceFollow);
    }
  }

  private pumpStreamingRender(): void {
    if (this.streamRenderTimer !== -1 || !this.streamTargetMsgId) {
      return;
    }
    const timerId: number = setTimeout(() => {
      this.streamRenderTimer = -1;
      this.renderStreamingFrame(false);
      if (this.streamTargetMsgId &&
        (this.renderedStreamContent.length < this.pendingStreamContent.length ||
          this.renderedStreamReasoningContent.length < this.pendingStreamReasoningContent.length)) {
        this.pumpStreamingRender();
      }
    }, 36);
    this.streamRenderTimer = timerId;
  }

  private scheduleStreamingRender(messageId: string, content: string, reasoningContent: string): void {
    if (this.streamTargetMsgId !== messageId) {
      this.streamTargetMsgId = messageId;
      this.renderedStreamContent = '';
      this.renderedStreamReasoningContent = '';
      this.lastFollowContentLength = 0;
    }
    this.pendingStreamContent = content;
    this.pendingStreamReasoningContent = reasoningContent;
    this.pumpStreamingRender();
  }

  private waitStreamingRenderComplete(): Promise<void> {
    const startAt: number = Date.now();
    return new Promise((resolve: () => void) => {
      const check = () => {
        const timeout: boolean = Date.now() - startAt > 12000;
        if (!this.streamTargetMsgId ||
          (this.renderedStreamContent.length >= this.pendingStreamContent.length &&
            this.renderedStreamReasoningContent.length >= this.pendingStreamReasoningContent.length) ||
          timeout) {
          resolve();
          return;
        }
        setTimeout(check, 24);
      };
      check();
    });
  }

  private clearStreamingRenderState(): void {
    if (this.streamRenderTimer !== -1) {
      clearTimeout(this.streamRenderTimer);
      this.streamRenderTimer = -1;
    }
    this.streamTargetMsgId = '';
    this.pendingStreamContent = '';
    this.renderedStreamContent = '';
    this.pendingStreamReasoningContent = '';
    this.renderedStreamReasoningContent = '';
    this.lastFollowContentLength = 0;
    this.lastFollowScrollTime = 0;
  }

  private scrollToBottom(delayMs: number = 0): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, delayMs);
  }

  async sendMessage() {
    if (!this.canSendMessage()) return;

    // Auto-create session if none exists
    if (!this.currentSessionId) {
      const session = await this.sessionManager.createNewSession(this.currentConfig!.id);
      this.currentSessionId = session.id;
    }

    const userMsg: ChatMessage = {
      id: Date.now().toString(),
      role: 'user',
      content: this.inputText,
      timestamp: Date.now(),
      images: this.attachedImages.length > 0 ? Array.from(this.attachedImages) : undefined,
      files: this.attachedFiles.length > 0 ? Array.from(this.attachedFiles) : undefined
    };
    this.messages = [...this.messages, userMsg];

    this.inputText = '';
    this.attachedImages = [];
    this.attachedFiles = [];
    this.isLoading = true;

    const aiMsgId = (Date.now() + 1).toString();
    this.streamingMsgId = aiMsgId;
    this.streamTargetMsgId = aiMsgId;
    this.pendingStreamContent = '';
    this.renderedStreamContent = '';
    this.pendingStreamReasoningContent = '';
    this.renderedStreamReasoningContent = '';
    this.lastFollowContentLength = 0;
    
    const aiMsg: ChatMessage = {
      id: aiMsgId,
      role: 'assistant',
      content: '', // Start empty
      reasoningContent: '',
      timestamp: Date.now()
    };
    this.messages = [...this.messages, aiMsg];
    
    // Scroll to the new message
    this.scrollToBottom(50);

    try {
      const config: AIServiceConfig = {
        apiEndpoint: this.currentConfig!.apiEndpoint,
        apiKey: this.currentConfig!.apiKey,
        model: this.currentConfig!.model,
        temperature: this.currentConfig!.temperature,
        maxTokens: this.currentConfig!.maxTokens
      };
      const service = new AIService(config);
      
      const finalMessage = await service.sendMessage(this.messages.slice(0, -1), (update: AIStreamUpdate) => {
        this.scheduleStreamingRender(aiMsgId, update.content, update.reasoningContent);
      });
      
      this.scheduleStreamingRender(
        aiMsgId,
        finalMessage.content,
        finalMessage.reasoningContent || ''
      );
      await this.waitStreamingRenderComplete();
      this.renderStreamingFrame(true);
    } catch (e) {
      console.error('[ChatPage] Send message error:', e);
      const index = this.messages.findIndex((m: ChatMessage) => m.id === aiMsgId);
      if (index !== -1) {
        const errorMessage: ChatMessage = {
          id: aiMsgId,
          role: 'assistant',
          reasoningContent: '',
          content: `请求失败: ${(e as Error).message || e}`,
          timestamp: Date.now()
        };
        const newMessages = [...this.messages];
        newMessages[index] = errorMessage;
        this.messages = newMessages;
      }
    } finally {
      this.clearStreamingRenderState();
      this.isLoading = false;
      this.streamingMsgId = '';
      await this.saveSession();
      
      // Final scroll to bottom
      this.scrollToBottom(100);
    }
  }

  async saveSession() {
    if (this.currentSessionId) {
      const session = this.sessionManager.getSession(this.currentSessionId);
      if (session) {
        session.messages = this.messages;
        // Auto-set title from first user message
        if ((session.title === 'New chat' || session.title === '新会话') && this.messages.length > 0) {
          const firstUserMsg = this.messages.find((m: ChatMessage) => m.role === 'user');
          if (firstUserMsg) {
            session.title = firstUserMsg.content.substring(0, 20);
          }
        }
        await this.sessionManager.updateSession(session);
        // Trigger history page refresh
        AppStorage.setOrCreate('sessionRefresh', Date.now());
      }
    }
  }

  @Builder
  SuggestionChip(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
        .margin({ bottom: 4 })
      Text(subtitle)
        .fontSize(12)
        .fontColor('#8E8E93')
    }
    .padding(12)
    .backgroundColor('#F2F2F7')
    .borderRadius(12)
    .margin({ right: 8, bottom: 8 })
    .onClick(() => {
      this.inputText = title;
    })
  }

  build() {
    NavDestination() {
      Column() {
        // 1. Custom Header
        Row() {
          // Left: Model Selector
          Row() {
            Text(this.currentModelName || '选择模型')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Image($r('sys.media.ohos_ic_public_arrow_down'))
              .width(14)
              .height(14)
              .fillColor('#999999')
              .margin({ left: 6 })
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.dialogController.open();
          })

          // Right: Actions
          Row({ space: 10 }) {
            // New Session
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_add'))
                .width(16)
                .height(16)
                .fillColor('#C7C7CC')
            }
            .width(32)
            .height(32)
            .backgroundColor('#F2F2F2')
            .onClick(() => this.startNewSession())

            // History
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_menu'))
                .width(18)
                .height(18)
                .fillColor('#444444')
            }
            .width(32)
            .height(32)
            .backgroundColor('#F2F2F2')
            .onClick(() => this.pageStack.pushPath({ name: 'History' }))

            // Settings
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_settings'))
                .width(18)
                .height(18)
                .fillColor('#C7C7CC')
            }
            .width(32)
            .height(32)
            .backgroundColor('#F2F2F2')
            .onClick(() => this.pageStack.pushPath({ name: 'Settings' }))
          }
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

        // 2. Chat List
        List({ scroller: this.scroller }) {
          if (this.messages.length === 0) {
            ListItem() {
              Column() {
                Image($r('app.media.ic_chat')) // Use generic icon or app logo
                  .width(60)
                  .height(60)
                  .fillColor('#E5E5EA')
                  .margin({ bottom: 16 })
                Text('有什么可以帮你的吗？')
                  .fontSize(18)
                  .fontColor('#1A1A1A')
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 40 })

                // Suggestion Chips
                Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                  this.SuggestionChip('写一个 Python 爬虫', '生成一个简洁可用的脚本')
                  this.SuggestionChip('解释量子纠缠', '用通俗语言说明原理')
                  this.SuggestionChip('制定健身计划', '减脂与体能提升方案')
                  this.SuggestionChip('翻译一段文本', '中英互译并保持语气自然')
                }
                .padding({ left: 20, right: 20 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .padding({ top: 100 })
            }
          }

          ForEach(this.messages, (msg: ChatMessage, index: number) => {
            ListItem() {
              MessageBubble({ 
                message: msg, 
                isStreaming: msg.id === this.streamingMsgId 
              })
            }
            .padding({ left: 16, right: 16 })
          }, (msg: ChatMessage) => msg.id + '_' + msg.timestamp.toString())

          // Loading indicator
          if (this.isLoading && !this.streamingMsgId) { // Show only if not streaming yet
            ListItem() {
              Row() {
                LoadingProgress().width(24).height(24).color('#999999')
                Text('思考中...')
                  .fontSize(14)
                  .fontColor('#999999')
                  .margin({ left: 8 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 12, bottom: 12 })
            }
          }

          // Bottom spacer
          ListItem().height(20)
        }
        .layoutWeight(1)
        .backgroundColor('#FFFFFF')
        .maintainVisibleContentPosition(true)
        .onScrollIndex(() => {
          // Auto scroll handled
        })

        // 3. Input Area
        Column() {
          // Attachments Preview
          if (this.attachedImages.length > 0 || this.attachedFiles.length > 0) {
            Column() {
              Scroll() {
                Row({ space: 8 }) {
                  // Image previews
                  ForEach(this.attachedImages, (img: string, index: number) => {
                    Stack({ alignContent: Alignment.TopEnd }) {
                      Image('data:image/jpeg;base64,' + img)
                        .width(60)
                        .height(60)
                        .borderRadius(8)
                        .objectFit(ImageFit.Cover)
                        .border({ width: 1, color: '#E5E5EA' })
                      
                      Button({ type: ButtonType.Circle }) {
                        Image($r('app.media.ic_close'))
                          .width(10)
                          .height(10)
                          .fillColor('#FFFFFF')
                      }
                      .width(20)
                      .height(20)
                      .backgroundColor('#FF3B30')
                      .margin({ top: -6, right: -6 })
                      .onClick(() => this.removeImage(index))
                    }
                  }, (img: string, index: number) => 'img_' + index.toString())

                  // File previews
                  ForEach(this.attachedFiles, (file: AttachedFile, index: number) => {
                    Stack({ alignContent: Alignment.TopEnd }) {
                      Column({ space: 4 }) {
                        Image($r('app.media.ic_file'))
                          .width(24)
                          .height(24)
                          .fillColor('#007AFF')
                        Text(file.name)
                          .fontSize(9)
                          .fontColor('#1A1A1A')
                          .maxLines(2)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                          .textAlign(TextAlign.Center)
                          .padding({ left: 4, right: 4 })
                      }
                      .width(60)
                      .height(60)
                      .backgroundColor('#F2F2F7')
                      .borderRadius(8)
                      .justifyContent(FlexAlign.Center)
                      .border({ width: 1, color: '#E5E5EA' })
                      
                      Button({ type: ButtonType.Circle }) {
                        Image($r('app.media.ic_close'))
                          .width(10)
                          .height(10)
                          .fillColor('#FFFFFF')
                      }
                      .width(20)
                      .height(20)
                      .backgroundColor('#FF3B30')
                      .margin({ top: -6, right: -6 })
                      .onClick(() => this.removeFile(index))
                    }
                  }, (file: AttachedFile, index: number) => 'file_' + index.toString())
                }
                .padding({ left: 16, right: 16 })
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
              .padding({ top: 12, bottom: 8 })
            }
            .width('100%')
            .backgroundColor('#FFFFFF')
            .border({ width: { bottom: 0.5 }, color: '#E5E5EA' })
          }

          // Input Row
          Row() {
            // Attachment Button
            Button({ type: ButtonType.Circle }) {
              Image($r('app.media.ic_add'))
                .width(20)
                .height(20)
                .fillColor('#8E8E93')
            }
            .width(36)
            .height(36)
            .backgroundColor('#F2F2F7')
            .margin({ right: 8 })
            .onClick(() => {
              this.attachmentDialogController.open();
            })

            // Text Input
            TextInput({ text: this.inputText, placeholder: '发送消息...' })
              .layoutWeight(1)
              .height(44)
              .backgroundColor('#F2F2F7')
              .borderRadius(22)
              .padding({ left: 16, right: 16 })
              .enterKeyType(EnterKeyType.Send)
              .enabled(!this.isLoading)
              .onChange((val) => { this.inputText = val; })
              .onSubmit(() => { 
                if (this.canSendMessage()) {
                  this.sendMessage(); 
                }
              })

            // Send Button
            Button({ type: ButtonType.Circle }) {
              if (this.isLoading) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#FFFFFF')
              } else {
                Image($r('app.media.ic_send'))
                  .width(20)
                  .height(20)
                  .fillColor('#FFFFFF')
              }
            }
            .width(44)
            .height(44)
            .backgroundColor(this.canSendMessage() ? '#007AFF' : '#C7C7CC')
            .enabled(this.canSendMessage())
            .margin({ left: 8 })
            .onClick(() => {
              if (this.canSendMessage()) {
                this.sendMessage();
              }
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 20 })
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
        .border({ width: { top: 0.5 }, color: '#F0F0F0' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
    }
    .hideTitleBar(true)
  }
}

