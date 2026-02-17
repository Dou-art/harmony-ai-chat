import { ModelSelector } from './ModelSelector';
import { APIConfig } from '../pages/APIConfig';

@CustomDialog
export struct ModelSelectorDialog {
  controller: CustomDialogController;
  @Link allConfigs: APIConfig[];
  @Prop currentConfigId: string = '';
  @Prop currentModel: string = '';
  @Link manualModel: string;
  onSelect: (configId: string, model: string) => void = () => {};

  build() {
    Column() {
      // Close button
      Row() {
        Blank()
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_close'))
            .width(18)
            .height(18)
            .fillColor('#8E8E93')
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
      }
      .width('100%')
      .padding({ right: 12, top: 8 })
      
      ModelSelector({
        allConfigs: this.allConfigs,
        currentConfigId: this.currentConfigId,
        currentModel: this.currentModel,
        manualModel: $manualModel,
        onSelect: (configId: string, model: string) => {
          this.onSelect(configId, model);
          if (this.controller) {
            this.controller.close();
          }
        }
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('78%')
    .constraintSize({ minHeight: 520, maxHeight: 720 })
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .clip(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
