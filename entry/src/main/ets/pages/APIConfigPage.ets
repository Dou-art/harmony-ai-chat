import { APIConfig, createDefaultAPIConfig } from './APIConfig';
import { ConfigManager } from './ConfigManager';
import { ConfigInput } from '../view/ConfigInput';
import { AIService, AIServiceConfig } from './AIService';

@Component
export struct APIConfigPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State config: APIConfig = createDefaultAPIConfig();
  @State availableModels: string[] = [];
  @State isLoadingModels: boolean = false;
  @State modelErrorMessage: string = '';
  @State formErrorMessage: string = '';
  @State temperatureInput: string = '0.7';
  private readonly tokenPresets: number[] = [0, 1024, 16000, 32000];
  private configManager: ConfigManager = ConfigManager.getInstance();
  private isNew: boolean = true;

  aboutToAppear() {
    const params = this.pageStack.getParamByIndex(this.pageStack.size() - 1) as APIConfig | null;
    if (params && params.id) {
      this.config = JSON.parse(JSON.stringify(params));
      this.isNew = false;
    }
    if (!this.config.favoriteModels) {
      this.config.favoriteModels = [];
    }
    this.temperatureInput = this.config.temperature.toString();
    this.config.maxTokens = this.normalizeTokenPreset(this.config.maxTokens);
  }

  private canSave(): boolean {
    if (!this.config.name.trim()) {
      return false;
    }
    if (!this.config.apiEndpoint.trim()) {
      return false;
    }
    if (!this.config.apiKey.trim()) {
      return false;
    }
    if (!this.config.model.trim()) {
      return false;
    }

    const temperature = Number(this.temperatureInput);
    if (Number.isNaN(temperature) || temperature < 0 || temperature > 2) {
      return false;
    }
    return true;
  }

  private applyAdvancedSettings(): boolean {
    const temperature = Number(this.temperatureInput);

    if (Number.isNaN(temperature) || temperature < 0 || temperature > 2) {
      this.formErrorMessage = '温度参数需在 0.0 到 2.0 之间。';
      return false;
    }

    this.config.temperature = temperature;
    this.config.maxTokens = this.normalizeTokenPreset(this.config.maxTokens);
    return true;
  }

  private normalizeTokenPreset(maxTokens: number): number {
    for (let i = 0; i < this.tokenPresets.length; i++) {
      if (this.tokenPresets[i] === maxTokens) {
        return maxTokens;
      }
    }
    if (maxTokens <= 0) {
      return 0;
    }
    let closest = 1024;
    let closestDiff = Math.abs(maxTokens - closest);
    for (let i = 1; i < this.tokenPresets.length; i++) {
      if (this.tokenPresets[i] === 0) {
        continue;
      }
      const diff = Math.abs(maxTokens - this.tokenPresets[i]);
      if (diff < closestDiff) {
        closest = this.tokenPresets[i];
        closestDiff = diff;
      }
    }
    return closest;
  }

  private tokenPresetLabel(maxTokens: number): string {
    if (maxTokens === 0) {
      return '自动';
    }
    return maxTokens.toString();
  }

  private tokenPresetDesc(maxTokens: number): string {
    if (maxTokens === 0) {
      return '由模型自动控制输出长度';
    }
    return `最多输出 ${maxTokens} tokens`;
  }

  async fetchModels() {
    if (!this.config.apiEndpoint.trim() || !this.config.apiKey.trim()) {
      this.modelErrorMessage = '请先填写 API 端点和 API 密钥。';
      return;
    }
    this.isLoadingModels = true;
    this.modelErrorMessage = '';
    try {
      const serviceConfig: AIServiceConfig = {
        apiEndpoint: this.config.apiEndpoint,
        apiKey: this.config.apiKey,
        model: this.config.model,
        temperature: this.config.temperature,
        maxTokens: this.config.maxTokens
      };
      const service = new AIService(serviceConfig);
      const fetchedModels = await service.fetchModels();
      const uniqueModels: string[] = [];
      const seen: Record<string, boolean> = {};
      for (let i = 0; i < fetchedModels.length; i++) {
        const model = fetchedModels[i].trim();
        if (!model || seen[model]) {
          continue;
        }
        seen[model] = true;
        uniqueModels.push(model);
      }
      this.availableModels = uniqueModels;
    } catch (e) {
      const err = e as Error;
      this.modelErrorMessage = `获取模型失败：${err.message || err}`;
    } finally {
      this.isLoadingModels = false;
    }
  }

  toggleFavoriteModel(model: string) {
    const index = this.config.favoriteModels.indexOf(model);
    if (index > -1) {
      this.config.favoriteModels = this.config.favoriteModels.filter((m: string) => m !== model);
    } else {
      this.config.favoriteModels = [...this.config.favoriteModels, model];
    }
  }

  async save() {
    this.formErrorMessage = '';
    if (!this.canSave()) {
      this.formErrorMessage = '请完整填写必填项，并检查高级参数。';
      return;
    }
    if (!this.applyAdvancedSettings()) {
      return;
    }

    if (this.isNew) {
      await this.configManager.addConfig(this.config);
    } else {
      await this.configManager.updateConfig(this.config);
    }
    AppStorage.setOrCreate('configRefresh', Date.now());
    this.pageStack.pop();
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 12 }) {
            Row() {
              Text('基础配置')
                .fontSize(17)
                .fontColor('#111111')
                .fontWeight(FontWeight.Medium)
              Blank()
              Text('必填')
                .fontSize(12)
                .fontColor('#6B6B6B')
            }
            .width('100%')

            ConfigInput({
              label: '配置名称',
              value: this.config.name,
              onChange: (val) => { this.config.name = val; }
            })

            ConfigInput({
              label: 'API 端点',
              value: this.config.apiEndpoint,
              onChange: (val) => { this.config.apiEndpoint = val; }
            })

            ConfigInput({
              label: 'API 密钥',
              value: this.config.apiKey,
              isPassword: true,
              onChange: (val) => { this.config.apiKey = val; }
            })

            ConfigInput({
              label: '默认模型',
              value: this.config.model,
              onChange: (val) => { this.config.model = val; }
            })
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 220 })
              .combine(
                TransitionEffect.translate({ y: 10 }).animation({ duration: 220, curve: Curve.FastOutSlowIn })
              )
          )

          Column({ space: 10 }) {
            Row() {
              Column({ space: 3 }) {
                Text('常用模型')
                  .fontSize(17)
                  .fontColor('#111111')
                  .fontWeight(FontWeight.Medium)
                Text('用于模型选择弹窗的快速切换')
                  .fontSize(12)
                  .fontColor('#7A7A7A')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button(this.isLoadingModels ? '拉取中...' : '拉取模型')
                .height(34)
                .fontSize(13)
                .fontColor('#222222')
                .backgroundColor('#F0F0F0')
                .borderRadius(8)
                .enabled(!this.isLoadingModels)
                .onClick(() => {
                  this.fetchModels();
                })
            }
            .width('100%')

            if (this.modelErrorMessage) {
              Text(this.modelErrorMessage)
                .fontSize(13)
                .fontColor('#CC3D3D')
                .width('100%')
            }

            if (this.config.favoriteModels.length > 0) {
              Text(`已选 ${this.config.favoriteModels.length} 个常用模型`)
                .fontSize(13)
                .fontColor('#666666')
                .width('100%')
                .margin({ top: 2, bottom: 4 })

              Column({ space: 8 }) {
                ForEach(this.config.favoriteModels, (model: string) => {
                  Row() {
                    Text(model)
                      .fontSize(14)
                      .fontColor('#111111')
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text('移除')
                      .fontSize(12)
                      .fontColor('#666666')
                      .onClick(() => {
                        this.toggleFavoriteModel(model);
                      })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .backgroundColor('#F7F7F7')
                  .borderRadius(10)
                }, (model: string) => model)
              }
              .width('100%')
            }

            if (this.availableModels.length > 0) {
              Text('从可用模型中勾选常用项')
                .fontSize(13)
                .fontColor('#666666')
                .width('100%')
                .margin({ top: 6 })

              List() {
                ForEach(this.availableModels, (model: string) => {
                  ListItem() {
                    Row() {
                      Checkbox()
                        .select(this.config.favoriteModels.includes(model))
                        .onChange(() => {
                          this.toggleFavoriteModel(model);
                        })
                        .margin({ right: 10 })

                      Text(model)
                        .fontSize(14)
                        .fontColor('#111111')
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .width('100%')
                    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                    .backgroundColor(this.config.favoriteModels.includes(model) ? '#F1F1F1' : '#FFFFFF')
                    .borderRadius(10)
                    .border({ width: 1, color: '#ECECEC', radius: 10 })
                  }
                }, (model: string) => model)
              }
              .height(260)
              .width('100%')
              .backgroundColor('#FAFAFA')
              .borderRadius(12)
              .padding(8)
              .divider({ strokeWidth: 0 })
              .edgeEffect(EdgeEffect.Spring)
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 240, delay: 40 })
              .combine(
                TransitionEffect.translate({ y: 12 }).animation({ duration: 240, curve: Curve.FastOutSlowIn, delay: 40 })
              )
          )

          Column({ space: 10 }) {
            Text('高级参数')
              .fontSize(17)
              .fontColor('#111111')
              .fontWeight(FontWeight.Medium)
              .width('100%')

            Column() {
              Text('温度 (0.0 ~ 2.0)')
                .fontSize(12)
                .fontColor('#7A7A7A')
                .margin({ bottom: 6, left: 4 })

              TextInput({ text: this.temperatureInput, placeholder: '例如 0.7' })
                .height(44)
                .fontSize(15)
                .fontColor('#111111')
                .backgroundColor('#F3F3F3')
                .borderRadius(10)
                .padding({ left: 12, right: 12 })
                .type(InputType.Normal)
                .onChange((val: string) => {
                  this.temperatureInput = val;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              Row() {
                Text('输出预算（tokens）')
                  .fontSize(12)
                  .fontColor('#7A7A7A')
                Blank()
                Text('当前：' + this.tokenPresetLabel(this.config.maxTokens))
                  .fontSize(12)
                  .fontColor('#7A7A7A')
              }
              .width('100%')
              .margin({ top: 6 })

              ForEach(this.tokenPresets, (preset: number) => {
                Row() {
                  Column({ space: 3 }) {
                    Text(this.tokenPresetLabel(preset))
                      .fontSize(15)
                      .fontColor('#111111')
                      .fontWeight(FontWeight.Medium)
                    Text(this.tokenPresetDesc(preset))
                      .fontSize(12)
                      .fontColor('#777777')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (this.config.maxTokens === preset) {
                    Image($r('app.media.ic_check'))
                      .width(16)
                      .height(16)
                      .fillColor('#111111')
                  }
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor(this.config.maxTokens === preset ? '#ECECEF' : '#F7F7F7')
                .borderRadius(10)
                .border({ width: 1, color: this.config.maxTokens === preset ? '#DADAE0' : '#ECECEC', radius: 10 })
                .onClick(() => {
                  this.config.maxTokens = preset;
                })
              }, (preset: number) => preset.toString())
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 260, delay: 80 })
              .combine(
                TransitionEffect.translate({ y: 14 }).animation({ duration: 260, curve: Curve.FastOutSlowIn, delay: 80 })
              )
          )

          if (this.formErrorMessage) {
            Text(this.formErrorMessage)
              .fontSize(13)
              .fontColor('#CC3D3D')
              .width('100%')
          }

          Button(this.isNew ? '保存配置' : '保存修改')
            .width('100%')
            .height(50)
            .backgroundColor(this.canSave() ? '#111111' : '#CFCFCF')
            .borderRadius(12)
            .fontSize(17)
            .fontColor('#FFFFFF')
            .enabled(this.canSave())
            .onClick(() => {
              this.save();
            })
            .transition(
              TransitionEffect.OPACITY.animation({ duration: 280, delay: 120 })
                .combine(
                  TransitionEffect.translate({ y: 16 }).animation({ duration: 280, curve: Curve.FastOutSlowIn, delay: 120 })
                )
            )

          Button('删除配置')
            .width('100%')
            .height(50)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .border({ width: 1, color: '#E1E1E1', radius: 12 })
            .fontSize(17)
            .fontColor('#A63D3D')
            .visibility(this.isNew ? Visibility.None : Visibility.Visible)
            .onClick(async () => {
              await this.configManager.deleteConfig(this.config.id);
              AppStorage.setOrCreate('configRefresh', Date.now());
              this.pageStack.pop();
            })
            .transition(
              TransitionEffect.OPACITY.animation({ duration: 300, delay: 150 })
                .combine(
                  TransitionEffect.translate({ y: 18 }).animation({ duration: 300, curve: Curve.FastOutSlowIn, delay: 150 })
                )
            )
        }
        .padding({ left: 16, right: 16, top: 14, bottom: 24 })
        .width('100%')
      }
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
    }
    .title(this.isNew ? '新建配置' : '编辑配置')
    .backgroundColor('#F5F5F5')
  }
}
