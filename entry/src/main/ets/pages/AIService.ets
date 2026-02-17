import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { ChatMessage } from './ChatMessage';

export interface AIServiceConfig {
  apiEndpoint: string;
  apiKey: string;
  model: string;
  temperature: number;
  maxTokens: number;
}

export interface AIStreamUpdate {
  content: string;
  reasoningContent: string;
}

interface MessageItem {
  role: string;
  content: string | ContentPart[];
}

interface ContentPart {
  type: string;
  text?: string;
  image_url?: ImageUrl;
}

interface ImageUrl {
  url: string;
}

interface ChoiceMessage {
  content: string;
  reasoning_content?: string;
}

interface Delta {
  content?: string;
  reasoning_content?: string;
}

interface Choice {
  message: ChoiceMessage;
  delta: Delta;
}

interface APIResponse {
  choices: Choice[];
}

interface RequestData {
  model: string;
  messages: MessageItem[];
  temperature: number;
  max_tokens?: number;
  stream: boolean;
}

interface ModelData {
  id: string;
}

interface ModelsResponse {
  data: ModelData[];
}

interface StreamChoice {
  delta: Delta;
  finish_reason: string | null;
}

interface StreamResponse {
  choices: StreamChoice[];
}

export class AIService {
  private config: AIServiceConfig;

  constructor(config: AIServiceConfig) {
    this.config = config;
  }

  async sendMessage(messages: ChatMessage[], onStream?: (update: AIStreamUpdate) => void): Promise<ChatMessage> {
    if (onStream) {
      return await this.sendMessageStream(messages, onStream);
    }
    return await this.sendMessageNormal(messages);
  }

  private async sendMessageNormal(messages: ChatMessage[]): Promise<ChatMessage> {
    const httpRequest = http.createHttp();

    try {
      const messageItems: MessageItem[] = [];
      for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
        
        // If message has images, use content array format
        if (msg.images && msg.images.length > 0) {
          const contentParts: ContentPart[] = [];
          
          // Add text content
          if (msg.content) {
            contentParts.push({
              type: 'text',
              text: msg.content
            });
          }
          
          // Add images
          for (let j = 0; j < msg.images.length; j++) {
            contentParts.push({
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${msg.images[j]}`
              }
            });
          }
          
          messageItems.push({
            role: msg.role,
            content: contentParts
          });
        } else {
          // Text only message
          messageItems.push({
            role: msg.role,
            content: msg.content
          });
        }
      }

      const requestData: RequestData = {
        model: this.config.model,
        messages: messageItems,
        temperature: this.config.temperature,
        stream: false
      };
      if (this.config.maxTokens > 0) {
        requestData.max_tokens = this.config.maxTokens;
      }

      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.config.apiKey}`
      };

      const response = await httpRequest.request(this.config.apiEndpoint, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(requestData),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 60000,
        readTimeout: 60000,
      });

      if (response.responseCode !== 200) {
        throw new Error(`API请求失败: ${response.responseCode}`);
      }

      const result: APIResponse = JSON.parse(response.result as string) as APIResponse;
      const content: string = result.choices[0]?.message?.content || '';
      const reasoningContent: string = result.choices[0]?.message?.reasoning_content || '';

      const responseMessage: ChatMessage = {
        id: (Date.now()).toString(),
        role: 'assistant',
        content: content,
        reasoningContent: reasoningContent || undefined,
        timestamp: Date.now()
      };

      return responseMessage;
    } catch (err) {
      throw new Error(`API调用失败: ${err}`);
    } finally {
      httpRequest.destroy();
    }
  }

  private sendMessageStream(messages: ChatMessage[], onStream: (update: AIStreamUpdate) => void): Promise<ChatMessage> {
    return new Promise<ChatMessage>((resolve, reject) => {
      const httpRequest = http.createHttp();

      const messageItems: MessageItem[] = [];
      for (let i = 0; i < messages.length; i++) {
        const msg = messages[i];
        
        // If message has images, use content array format
        if (msg.images && msg.images.length > 0) {
          const contentParts: ContentPart[] = [];
          
          // Add text content
          if (msg.content) {
            contentParts.push({
              type: 'text',
              text: msg.content
            });
          }
          
          // Add images
          for (let j = 0; j < msg.images.length; j++) {
            contentParts.push({
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${msg.images[j]}`
              }
            });
          }
          
          messageItems.push({
            role: msg.role,
            content: contentParts
          });
        } else {
          // Text only message
          messageItems.push({
            role: msg.role,
            content: msg.content
          });
        }
      }

      const requestData: RequestData = {
        model: this.config.model,
        messages: messageItems,
        temperature: this.config.temperature,
        stream: true
      };
      if (this.config.maxTokens > 0) {
        requestData.max_tokens = this.config.maxTokens;
      }

      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.config.apiKey}`,
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache'
      };

      let fullContent: string = '';
      let fullReasoningContent: string = '';
      const messageId: string = Date.now().toString();
      let buffer: string = '';
      let lastEmittedContentLength: number = -1;
      let lastEmittedReasoningLength: number = -1;

      const emitUpdate = (): void => {
        if (lastEmittedContentLength === fullContent.length &&
          lastEmittedReasoningLength === fullReasoningContent.length) {
          return;
        }
        lastEmittedContentLength = fullContent.length;
        lastEmittedReasoningLength = fullReasoningContent.length;
        onStream({
          content: fullContent,
          reasoningContent: fullReasoningContent
        });
      };

      // Register streaming data handler - receives chunks in real time
      const decoder = util.TextDecoder.create('utf-8');
      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        try {
          const chunk: string = decoder.decode(new Uint8Array(data));
          buffer += chunk;

          // Process complete SSE lines from buffer
          let lines: string[] = buffer.split('\n');
          // Keep the last potentially incomplete line in buffer
          buffer = lines.pop() || '';

          for (let i = 0; i < lines.length; i++) {
            const line: string = lines[i].trim();

            if (line === '') {
              continue;
            }

            // Fallback: Handle non-stream JSON response (if provider ignores stream: true)
            if (!line.startsWith('data:') && line.startsWith('{')) {
              try {
                 const json = JSON.parse(line) as APIResponse;
                 if (json.choices && json.choices.length > 0) {
                   const content = json.choices[0].message?.content || '';
                   const reasoning = json.choices[0].message?.reasoning_content || '';
                   if (content) {
                     fullContent += content;
                   }
                   if (reasoning) {
                     fullReasoningContent += reasoning;
                   }
                   if (content || reasoning) {
                     emitUpdate();
                   }
                 }
                 continue;
              } catch (e) {
                console.warn('[AIService] Line starting with { but not valid JSON');
              }
            }

            if (!line.startsWith('data:')) {
              continue;
            }

            const sseData: string = line.substring(5).trim();

            if (sseData === '[DONE]') {
              continue;
            }

            try {
              const json: StreamResponse = JSON.parse(sseData) as StreamResponse;
              if (json.choices && json.choices.length > 0) {
                const delta: Delta = json.choices[0].delta;
                if (delta) {
                   const reasoning = delta.reasoning_content || '';
                   const content = delta.content || '';
                   
                   if (reasoning || content) {
                     fullReasoningContent += reasoning;
                     fullContent += content;
                     emitUpdate();
                   }
                }
              }
            } catch (parseErr) {
              console.warn('[AIService] SSE parse error:', line, parseErr);
            }
          }
        } catch (e) {
          console.error('[AIService] dataReceive error:', e);
        }
      });

      // Handle stream end
      httpRequest.on('dataEnd', () => {
        // Process any remaining data in buffer
        if (buffer.trim().length > 0) {
           const line = buffer.trim();
           // Try parsing as JSON first
           if (line.startsWith('{')) {
              try {
                 const json = JSON.parse(line) as APIResponse;
                 if (json.choices && json.choices.length > 0) {
                    const content = json.choices[0].message?.content || '';
                    const reasoning = json.choices[0].message?.reasoning_content || '';
                    if (content) {
                      fullContent += content;
                    }
                    if (reasoning) {
                      fullReasoningContent += reasoning;
                    }
                    if (content || reasoning) {
                      emitUpdate();
                    }
                 }
              } catch (e) {}
           }
           
           if (line.startsWith('data:')) {
             const sseData: string = line.substring(5).trim();
              if (sseData !== '[DONE]') {
                try {
                  const json: StreamResponse = JSON.parse(sseData) as StreamResponse;
                  if (json.choices && json.choices.length > 0) {
                    const delta: Delta = json.choices[0].delta;
                    if (delta) {
                      const content = delta.content || '';
                      const reasoning = delta.reasoning_content || '';
                      if (content) {
                        fullContent += content;
                      }
                      if (reasoning) {
                        fullReasoningContent += reasoning;
                      }
                      if (content || reasoning) {
                      emitUpdate();
                      }
                    }
                  }
                } catch (parseErr) {
                  // ignore
                }
              }
           }
        }

        const responseMessage: ChatMessage = {
          id: messageId,
          role: 'assistant',
          content: fullContent,
          reasoningContent: fullReasoningContent || undefined,
          timestamp: Date.now()
        };

        httpRequest.off('dataReceive');
        httpRequest.off('dataEnd');
        httpRequest.destroy();
        resolve(responseMessage);
      });

      // Start streaming request
      httpRequest.requestInStream(this.config.apiEndpoint, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(requestData),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 60000,
        readTimeout: 180000,
      }).then((responseCode: number) => {
        if (responseCode !== 200) {
          httpRequest.off('dataReceive');
          httpRequest.off('dataEnd');
          httpRequest.destroy();
          reject(new Error(`API请求失败: ${responseCode}`));
        }
      }).catch((err: Error) => {
        httpRequest.off('dataReceive');
        httpRequest.off('dataEnd');
        httpRequest.destroy();
        reject(new Error(`API调用失败: ${err}`));
      });
    });
  }

  async fetchModels(): Promise<string[]> {
    const httpRequest = http.createHttp();

    try {
      const header: Record<string, string> = {
        'Authorization': `Bearer ${this.config.apiKey}`
      };

      // Construct models endpoint URL from chat endpoint
      let modelsEndpoint = this.config.apiEndpoint;
      
      // Remove /chat/completions if present and add /models
      if (modelsEndpoint.endsWith('/chat/completions')) {
        modelsEndpoint = modelsEndpoint.replace('/chat/completions', '/models');
      } else if (modelsEndpoint.endsWith('/completions')) {
        modelsEndpoint = modelsEndpoint.replace('/completions', '/models');
      } else {
        // Assume base URL, append /models
        modelsEndpoint = modelsEndpoint.replace(/\/$/, '') + '/models';
      }
      
      const response = await httpRequest.request(modelsEndpoint, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 30000,
      });

      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
      }

      const result: ModelsResponse = JSON.parse(response.result as string) as ModelsResponse;
      const models: string[] = [];

      for (let i = 0; i < result.data.length; i++) {
        models.push(result.data[i].id);
      }

      return models.sort();
    } catch (err) {
      console.error('[AIService] fetchModels error:', err);
      throw new Error(`获取模型失败: ${err.message || err}`);
    } finally {
      httpRequest.destroy();
    }
  }
}
