import { APIConfig } from '../pages/APIConfig';

interface ModelItem {
  configId: string;
  configName: string;
  model: string;
  key: string;
}

interface ModelGroup {
  configId: string;
  configName: string;
  models: ModelItem[];
  key: string;
}

@Component
export struct ModelSelector {
  @Prop allConfigs: APIConfig[] = [];
  @Prop currentConfigId: string = '';
  @Prop currentModel: string = '';
  @Link manualModel: string;
  @State searchInput: string = '';
  @State searchKeyword: string = '';
  @State displayedGroups: ModelGroup[] = [];
  onSelect?: (configId: string, model: string) => void;

  aboutToAppear(): void {
    this.applySearch('');
  }

  private normalizeText(value: string): string {
    return value.trim().toLowerCase();
  }

  private containsModel(models: string[], candidate: string): boolean {
    const target = this.normalizeText(candidate);
    for (let i = 0; i < models.length; i++) {
      if (this.normalizeText(models[i]) === target) {
        return true;
      }
    }
    return false;
  }

  private collectFavoriteModels(config: APIConfig): string[] {
    const models: string[] = [];

    if (!config.favoriteModels || config.favoriteModels.length === 0) {
      return models;
    }

    for (let i = 0; i < config.favoriteModels.length; i++) {
      const model = config.favoriteModels[i].trim();
      if (!model) {
        continue;
      }
      if (!this.containsModel(models, model)) {
        models.push(model);
      }
    }

    return models;
  }

  private buildDisplayedGroups(keywordInput: string): ModelGroup[] {
    const groups: ModelGroup[] = [];
    const keyword = this.normalizeText(keywordInput);

    for (let i = 0; i < this.allConfigs.length; i++) {
      const config = this.allConfigs[i];
      const models = this.collectFavoriteModels(config);
      const matchedModels: ModelItem[] = [];

      for (let j = 0; j < models.length; j++) {
        const model = models[j];
        if (keyword && !this.normalizeText(model).includes(keyword)) {
          continue;
        }

        matchedModels.push({
          configId: config.id,
          configName: config.name,
          model: model,
          key: config.id + '_' + model
        });
      }

      if (matchedModels.length > 0) {
        groups.push({
          configId: config.id,
          configName: config.name,
          models: matchedModels,
          key: 'group_' + config.id
        });
      }
    }

    return groups;
  }

  private getDisplayedModelCount(): number {
    let count = 0;
    for (let i = 0; i < this.displayedGroups.length; i++) {
      count += this.displayedGroups[i].models.length;
    }
    return count;
  }

  private isCurrentSelection(configId: string, model: string): boolean {
    return configId === this.currentConfigId && model === this.currentModel;
  }

  private applySearch(keywordInput: string): void {
    const keyword = keywordInput.trim();
    this.searchKeyword = keyword;
    this.displayedGroups = this.buildDisplayedGroups(keyword);
  }

  private triggerSearch(): void {
    const keyword = this.searchInput.trim();
    this.searchInput = keyword;
    this.applySearch(keyword);
  }

  build() {
    Column() {
      Row()
        .width(36)
        .height(5)
        .backgroundColor('#E5E5EA')
        .borderRadius(2.5)
        .margin({ top: 10, bottom: 20 })

      Text('选择模型')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: 20, bottom: 20 })

      Row() {
        TextInput({ text: this.searchInput, placeholder: '搜索模型...' })
          .layoutWeight(1)
          .height(42)
          .backgroundColor(Color.Transparent)
          .fontSize(15)
          .caretColor('#111111')
          .padding({ left: 10, right: 8 })
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => {
            this.searchInput = value;
          })
          .onSubmit(() => {
            this.triggerSearch();
          })

        Button('搜索')
          .width(92)
          .height(36)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#111111')
          .borderRadius(10)
          .margin({ left: 8 })
          .onClick(() => {
            this.triggerSearch();
          })
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
      .margin({ left: 20, right: 20, bottom: 10 })

      if (this.searchKeyword) {
        Text('关键词: ' + this.searchKeyword + '  结果: ' + this.getDisplayedModelCount().toString())
          .fontSize(12)
          .fontColor('#8A8A8A')
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 8 })
      }

      List() {
        ForEach(this.displayedGroups, (group: ModelGroup, groupIndex: number) => {
          ListItem() {
            Row() {
              Text(group.configName)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#666666')

              Text(group.models.length.toString() + ' 个')
                .fontSize(12)
                .fontColor('#A0A0A0')
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 8 })
            .backgroundColor('#FFFFFF')
          }

          ForEach(group.models, (item: ModelItem, index: number) => {
            ListItem() {
              Row() {
                Stack({ alignContent: Alignment.Center }) {
                  Circle({ width: 40, height: 40 })
                    .fill('#F0F0F0')
                  Text(item.model.substring(0, 1).toUpperCase())
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#222222')
                }
                .margin({ right: 14 })

                Column() {
                  Text(item.model)
                    .fontSize(17)
                    .fontColor('#111111')
                    .fontWeight(this.isCurrentSelection(item.configId, item.model) ? FontWeight.Medium : FontWeight.Regular)

                  if (item.configId === this.currentConfigId) {
                    Text('当前配置')
                      .fontSize(12)
                      .fontColor('#8A8A8A')
                      .margin({ top: 4 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (this.isCurrentSelection(item.configId, item.model)) {
                  Image($r('app.media.ic_check'))
                    .width(20)
                    .height(20)
                    .fillColor('#111111')
                }
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .backgroundColor(this.isCurrentSelection(item.configId, item.model) ? '#F7F7F7' : '#FFFFFF')
              .onClick(() => {
                if (this.onSelect) {
                  this.onSelect(item.configId, item.model);
                }
                this.manualModel = item.model;
              })
            }
            .transition(
              TransitionEffect.OPACITY.animation({
                duration: 220,
                curve: Curve.Friction,
                delay: groupIndex * 28 + index * 18
              }).combine(TransitionEffect.translate({ y: 10 }))
            )
          }, (item: ModelItem) => item.key)
        }, (group: ModelGroup) => group.key)

        if (this.getDisplayedModelCount() === 0) {
          ListItem() {
            Column() {
              Image($r('app.media.ic_settings'))
                .width(56)
                .height(56)
                .fillColor('#D0D0D0')
                .margin({ top: 60, bottom: 16 })

              Text(this.searchKeyword ? '未找到匹配模型' : '暂无可用模型')
                .fontSize(17)
                .fontColor('#555555')
                .margin({ bottom: 8 })

              Text(this.searchKeyword ? '请尝试其他关键词' : '请在设置中添加或编辑模型')
                .fontSize(14)
                .fontColor('#9A9A9A')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
