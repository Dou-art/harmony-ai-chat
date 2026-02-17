import { preferences } from '@kit.ArkData';
import { APIConfig, createDefaultAPIConfig } from './APIConfig';

export class ConfigManager {
  private static instance: ConfigManager;
  private dataPreferences: preferences.Preferences | null = null;
  private configs: APIConfig[] = [];
  private currentConfigId: string = '';

  static getInstance(): ConfigManager {
    if (!ConfigManager.instance) {
      ConfigManager.instance = new ConfigManager();
    }
    return ConfigManager.instance;
  }

  async init(context: Context): Promise<void> {
    try {
      this.dataPreferences = await preferences.getPreferences(context, 'ai_configs');
      await this.loadConfigs();
    } catch (err) {
      console.error('ConfigManager init failed:', err);
    }
  }

  private async loadConfigs(): Promise<void> {
    try {
      const configsJson = await this.dataPreferences?.get('configs', '[]') as string;
      this.configs = JSON.parse(configsJson) as APIConfig[];
      
      // Backward compatibility: ensure favoriteModels exists
      for (let i = 0; i < this.configs.length; i++) {
        if (!this.configs[i].favoriteModels) {
          this.configs[i].favoriteModels = [];
        }
      }
      
      this.currentConfigId = await this.dataPreferences?.get('currentConfigId', '') as string;
      
      if (this.configs.length === 0) {
        const defaultConfig = createDefaultAPIConfig();
        this.configs.push(defaultConfig);
        this.currentConfigId = defaultConfig.id;
        await this.saveConfigs();
      }

      if (!this.currentConfigId || !this.configs.find(c => c.id === this.currentConfigId)) {
        const defaultConfig = this.configs.find(c => c.isDefault) || this.configs[0];
        if (defaultConfig) {
          this.currentConfigId = defaultConfig.id;
        }
      }
    } catch (err) {
      console.error('加载配置失败:', err);
      const defaultConfig = createDefaultAPIConfig();
      this.configs = [defaultConfig];
      this.currentConfigId = defaultConfig.id;
    }
  }

  private async saveConfigs(): Promise<void> {
    try {
      const configsJson = JSON.stringify(this.configs);
      await this.dataPreferences?.put('configs', configsJson);
      await this.dataPreferences?.put('currentConfigId', this.currentConfigId);
      await this.dataPreferences?.flush();
      // Notify config change for real-time sync
      AppStorage.setOrCreate('configRefresh', Date.now());
    } catch (err) {
      console.error('保存配置失败:', err);
    }
  }

  getConfigs(): APIConfig[] {
    return this.configs;
  }

  getCurrentConfig(): APIConfig | undefined {
    return this.configs.find(c => c.id === this.currentConfigId);
  }

  async addConfig(config: APIConfig): Promise<void> {
    config.id = Date.now().toString();
    config.createdAt = Date.now();
    config.updatedAt = Date.now();
    if (!config.favoriteModels) {
      config.favoriteModels = [];
    }
    this.configs.push(config);
    // Auto-set new config as current
    this.currentConfigId = config.id;
    await this.saveConfigs();
  }

  async updateConfig(config: APIConfig): Promise<void> {
    const index = this.configs.findIndex(c => c.id === config.id);
    if (index !== -1) {
      config.updatedAt = Date.now();
      this.configs[index] = config;
      await this.saveConfigs();
    }
  }

  async deleteConfig(id: string): Promise<void> {
    if (this.configs.length <= 1) {
      return;
    }
    const index = this.configs.findIndex(c => c.id === id);
    if (index !== -1) {
      this.configs.splice(index, 1);
      if (this.currentConfigId === id) {
        const defaultConfig = this.configs.find(c => c.isDefault) || this.configs[0];
        if (defaultConfig) {
          this.currentConfigId = defaultConfig.id;
        }
      }
      await this.saveConfigs();
    }
  }

  async setCurrentConfig(id: string): Promise<void> {
    if (this.configs.find(c => c.id === id)) {
      this.currentConfigId = id;
      await this.saveConfigs();
    }
  }

  async setDefaultConfig(id: string): Promise<void> {
    this.configs.forEach(c => {
      c.isDefault = c.id === id;
    });
    await this.saveConfigs();
  }
}
