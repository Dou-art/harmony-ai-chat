import { preferences } from '@kit.ArkData';
import { ChatMessage } from './ChatMessage';

export interface Session {
  id: string;
  title: string;
  messages: ChatMessage[];
  configId: string;
  createdAt: number;
}

export class SessionManager {
  private static instance: SessionManager;
  private dataPreferences: preferences.Preferences | null = null;
  private sessions: Session[] = [];

  private currentSessionId: string = '';

  static getInstance(): SessionManager {
    if (!SessionManager.instance) {
      SessionManager.instance = new SessionManager();
    }
    return SessionManager.instance;
  }

  async init(context: Context): Promise<void> {
    try {
      this.dataPreferences = await preferences.getPreferences(context, 'ai_sessions');
      await this.loadSessions();
    } catch (err) {
      console.error('SessionManager init failed:', err);
    }
  }

  private async loadSessions(): Promise<void> {
    try {
      const sessionsJson = await this.dataPreferences?.get('sessions', '[]') as string;
      this.sessions = JSON.parse(sessionsJson) as Session[];
      this.currentSessionId = await this.dataPreferences?.get('currentSessionId', '') as string;
    } catch (err) {
      console.error('加载会话失败:', err);
      this.sessions = [];
    }
  }

  private async saveSessions(): Promise<void> {
    try {
      const sessionsJson = JSON.stringify(this.sessions);
      await this.dataPreferences?.put('sessions', sessionsJson);
      await this.dataPreferences?.put('currentSessionId', this.currentSessionId);
      await this.dataPreferences?.flush();
    } catch (err) {
      console.error('保存会话失败:', err);
    }
  }

  getSessions(): Session[] {
    return this.sessions;
  }

  getSession(id: string): Session | undefined {
    return this.sessions.find(s => s.id === id);
  }

  getCurrentSession(): Session | undefined {
    return this.sessions.find(s => s.id === this.currentSessionId);
  }

  async setCurrentSession(id: string): Promise<void> {
    this.currentSessionId = id;
    await this.saveSessions();
  }

  async addSession(session: Session): Promise<void> {
    this.sessions.unshift(session);
    this.currentSessionId = session.id;
    await this.saveSessions();
  }

  async updateSession(session: Session): Promise<void> {
    const index = this.sessions.findIndex(s => s.id === session.id);
    if (index !== -1) {
      this.sessions[index] = session;
      await this.saveSessions();
    }
  }

  async deleteSession(id: string): Promise<void> {
    const index = this.sessions.findIndex(s => s.id === id);
    if (index !== -1) {
      this.sessions.splice(index, 1);
      if (this.currentSessionId === id) {
          this.currentSessionId = this.sessions.length > 0 ? this.sessions[0].id : '';
      }
      await this.saveSessions();
    }
  }

  async createNewSession(configId: string = ''): Promise<Session> {
    const newSession: Session = {
      id: Date.now().toString(),
      title: '新会话',
      messages: [],
      configId: configId,
      createdAt: Date.now()
    };
    await this.addSession(newSession);
    return newSession;
  }
}
