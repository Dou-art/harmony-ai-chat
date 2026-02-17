import { SessionManager, Session } from './SessionManager';

interface SessionGroup {
  key: string;
  title: string;
  sessions: Session[];
}

@Component
export struct HistoryPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State groupedSessions: SessionGroup[] = [];
  @StorageProp('sessionRefresh') @Watch('onSessionRefresh') sessionRefresh: number = 0;
  private sessionManager: SessionManager = SessionManager.getInstance();

  async aboutToAppear() {
    this.loadSessions();
  }

  onSessionRefresh() {
    this.loadSessions();
  }

  loadSessions() {
    const sessions = this.sessionManager.getSessions()
      .slice()
      .sort((a: Session, b: Session) => b.createdAt - a.createdAt);
    this.groupedSessions = this.buildSessionGroups(sessions);
  }

  async deleteSession(id: string) {
    await this.sessionManager.deleteSession(id);
    this.loadSessions();
    AppStorage.setOrCreate('sessionRefresh', Date.now());
  }

  async selectSession(id: string) {
    await this.sessionManager.setCurrentSession(id);
    AppStorage.setOrCreate('sessionRefresh', Date.now());
    this.pageStack.pop();
  }

  private getDayStart(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  private formatGroupTitle(dayStart: number): string {
    const todayStart = this.getDayStart(Date.now());
    const yesterdayStart = todayStart - 24 * 60 * 60 * 1000;
    if (dayStart === todayStart) {
      return '今天';
    }
    if (dayStart === yesterdayStart) {
      return '昨天';
    }

    const date = new Date(dayStart);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private buildSessionGroups(sessions: Session[]): SessionGroup[] {
    const groupsMap: Record<string, SessionGroup> = {};

    for (let i = 0; i < sessions.length; i++) {
      const session = sessions[i];
      const dayStart = this.getDayStart(session.createdAt);
      const key = dayStart.toString();
      if (!groupsMap[key]) {
        groupsMap[key] = {
          key: key,
          title: this.formatGroupTitle(dayStart),
          sessions: []
        };
      }
      groupsMap[key].sessions.push(session);
    }

    const keys = Object.keys(groupsMap).sort((a: string, b: string) => Number(b) - Number(a));
    const groups: SessionGroup[] = [];
    for (let i = 0; i < keys.length; i++) {
      groups.push(groupsMap[keys[i]]);
    }
    return groups;
  }

  build() {
    NavDestination() {
      List() {
        if (this.groupedSessions.length === 0) {
          ListItem() {
            Column() {
              Text('暂无历史会话')
                .fontSize(18)
                .fontColor('#222222')
                .fontWeight(FontWeight.Medium)
              Text('请在主页顶部点击 + 新建会话')
                .fontSize(14)
                .fontColor('#888888')
                .margin({ top: 8 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 120 })
          }
        }

        ForEach(this.groupedSessions, (group: SessionGroup, groupIndex: number) => {
          ListItem() {
            Row() {
              Text(group.title)
                .fontSize(13)
                .fontColor('#7A7A7A')
                .fontWeight(FontWeight.Medium)

              Text(group.sessions.length.toString() + ' 条')
                .fontSize(12)
                .fontColor('#A0A0A0')
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 18, bottom: 10 })
          }
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 220, delay: groupIndex * 40 })
              .combine(
                TransitionEffect.translate({ y: 8 }).animation({ duration: 220, delay: groupIndex * 40 })
              )
          )

          ForEach(group.sessions, (session: Session, sessionIndex: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(session.title || '新会话')
                    .fontSize(16)
                    .fontColor('#111111')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(this.formatTime(session.createdAt))
                    .fontSize(12)
                    .fontColor('#8A8A8A')
                    .margin({ top: 6 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Image($r('sys.media.ohos_ic_public_arrow_right'))
                  .width(14)
                  .height(14)
                  .fillColor('#B0B0B0')
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .margin({ left: 14, right: 14, bottom: 10 })
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .border({ width: 1, color: '#ECECEC', radius: 14 })
              .onClick(() => {
                this.selectSession(session.id);
              })
            }
            .swipeAction({
              end: () => { this.SwipeToDeleteBuilder(session.id) }
            })
            .transition(
              TransitionEffect.OPACITY.animation({ duration: 240, delay: groupIndex * 30 + sessionIndex * 20 })
                .combine(
                  TransitionEffect.translate({ y: 12 })
                    .animation({ duration: 240, curve: Curve.FastOutSlowIn, delay: groupIndex * 30 + sessionIndex * 20 })
                )
            )
          }, (session: Session) => session.id)
        }, (group: SessionGroup) => group.key)

        ListItem() {
          Column() {}
            .width('100%')
            .height(20)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')
      .divider({ strokeWidth: 0 })
      .edgeEffect(EdgeEffect.Spring)
    }
    .title('历史记录')
    .backgroundColor('#F5F5F5')
  }

  @Builder SwipeToDeleteBuilder(sessionId: string) {
    Row() {
      Button('删除')
        .type(ButtonType.Normal)
        .backgroundColor('#FF3B30')
        .fontColor('#FFFFFF')
        .height('100%')
        .onClick(() => {
          this.deleteSession(sessionId);
        })
    }
  }
}
