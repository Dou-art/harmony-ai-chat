export interface APIConfig {
  id: string;
  name: string;
  apiEndpoint: string;
  apiKey: string;
  model: string;
  temperature: number;
  maxTokens: number;
  isDefault: boolean;
  favoriteModels: string[]; // User-selected favorite models for quick switching
  createdAt: number;
  updatedAt: number;
}

export function createDefaultAPIConfig(): APIConfig {
  return {
    id: Date.now().toString(),
    name: '默认配置',
    apiEndpoint: 'https://api.openai.com/v1/chat/completions',
    apiKey: '',
    model: 'gpt-4',
    temperature: 0.7,
    maxTokens: 1024,
    isDefault: true,
    favoriteModels: [],
    createdAt: Date.now(),
    updatedAt: Date.now()
  };
}
