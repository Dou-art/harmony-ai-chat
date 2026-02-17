import { APIConfig } from './APIConfig';
import { ConfigManager } from './ConfigManager';

@Component
export struct SettingsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State configs: APIConfig[] = [];
  @State currentConfigId: string = '';
  private configManager: ConfigManager = ConfigManager.getInstance();

  async aboutToAppear() {
    await this.loadConfigs();
  }

  async loadConfigs() {
    this.configs = this.configManager.getConfigs();
    const currentConfig = this.configManager.getCurrentConfig();
    this.currentConfigId = currentConfig?.id || '';
  }

  async selectConfig(config: APIConfig) {
    await this.configManager.setCurrentConfig(config.id);
    this.currentConfigId = config.id;
    // Trigger config refresh in ChatPage
    AppStorage.setOrCreate('configRefresh', Date.now());
  }

  build() {
    NavDestination() {
      List() {
        ListItem() {
          Text('API 配置')
            .fontSize(14)
            .fontColor('#8E8E93')
            .width('100%')
            .padding({ left: 16, top: 20, bottom: 8 })
        }

        ForEach(this.configs, (config: APIConfig, index: number) => {
          ListItem() {
            Row() {
              Column() {
                Row() {
                  Text(config.name)
                    .fontSize(17)
                    .fontColor('#000000')
                    .fontWeight(FontWeight.Medium)
                  if (config.id === this.currentConfigId) {
                    Text('当前')
                      .fontSize(12)
                      .fontColor('#007AFF')
                      .backgroundColor('#E5F2FF')
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .borderRadius(4)
                      .margin({ left: 8 })
                  }
                }
                if (config.isDefault) {
                  Text('默认')
                    .fontSize(12)
                    .fontColor('#8E8E93')
                    .margin({ top: 2 })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Image($r('app.media.ic_settings'))
                .width(20)
                .height(20)
                .fillColor('#C7C7CC')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor('#FFFFFF')
            .onClick(() => {
              this.pageStack.pushPath({ name: 'APIConfig', param: config });
            })
          }
          .swipeAction({
            start: () => { this.SetCurrentConfigBuilder(config) }
          })
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 300, delay: index * 50 })
            .combine(
              TransitionEffect.translate({ y: 20 })
              .animation({ duration: 300, curve: Curve.FastOutSlowIn, delay: index * 50 })
            )
          )
        })

        ListItem() {
          Row() {
            Text('新增配置')
              .fontSize(17)
              .fontColor('#007AFF')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor('#FFFFFF')
          .onClick(() => {
             this.pageStack.pushPath({ name: 'APIConfig', param: null });
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F2F7')
      .divider({ strokeWidth: 0.5, color: '#C6C6C8', startMargin: 16, endMargin: 0 })
    }
    .title('设置')
    .backgroundColor('#F2F2F7')
    .onShown(() => {
      // Reload configs when returning from APIConfigPage
      this.loadConfigs();
    })
  }

  @Builder SetCurrentConfigBuilder(config: APIConfig) {
    Row() {
      Button(config.id === this.currentConfigId ? '已选中' : '设为当前')
        .type(ButtonType.Normal)
        .backgroundColor('#007AFF')
        .fontColor('#FFFFFF')
        .height('100%')
        .enabled(config.id !== this.currentConfigId)
        .onClick(async () => {
          await this.selectConfig(config);
        })
    }
  }
}
