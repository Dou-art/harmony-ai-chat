import { ChatPage } from './ChatPage';
import { HistoryPage } from './HistoryPage';
import { SettingsPage } from './SettingsPage';
import { APIConfigPage } from './APIConfigPage';
import { SessionManager } from './SessionManager';
import { ConfigManager } from './ConfigManager';
import common from '@ohos.app.ability.common';

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @State isReady: boolean = false;

  private sessionManager: SessionManager = SessionManager.getInstance();
  private configManager: ConfigManager = ConfigManager.getInstance();

  async aboutToAppear() {
    AppStorage.setOrCreate('sessionRefresh', 0);
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await this.configManager.init(context);
    await this.sessionManager.init(context);
    this.isReady = true;
  }

  @Builder PageMap(name: string) {
    if (name === 'Chat') {
      ChatPage()
    } else if (name === 'History') {
      HistoryPage()
    } else if (name === 'Settings') {
      SettingsPage()
    } else if (name === 'APIConfig') {
      APIConfigPage()
    }
  }

  build() {
    Navigation(this.pageStack) {
      if (this.isReady) {
        ChatPage()
      } else {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#007AFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F2F2F7')
      }
    }
    .mode(NavigationMode.Stack)
    .navDestination(this.PageMap)
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }
}
