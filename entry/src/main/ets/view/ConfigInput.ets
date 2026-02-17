@Component
export struct ConfigInput {
  @Prop label: string = '';
  @Prop value: string = '';
  onChange: (value: string) => void = (value: string): void => {};
  @Prop isPassword: boolean = false;

  build() {
    Column() {
      Text(this.label)
        .fontSize(12)
        .fontColor('#8E8E93')
        .margin({ bottom: 6, left: 4 })
        .fontWeight(FontWeight.Medium)
        
      TextInput({ text: this.value, placeholder: `输入${this.label}` })
        .width('100%')
        .height(44)
        .type(this.isPassword ? InputType.Password : InputType.Normal)
        .backgroundColor('#F2F2F7')
        .borderRadius(10)
        .fontSize(16)
        .fontColor('#000000')
        .padding({ left: 12, right: 12 })
        .onChange((value: string): void => {
          this.onChange(value);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }
}
