export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  reasoningContent?: string;
  timestamp: number;
  images?: string[]; // Base64 encoded images
  files?: AttachedFile[];
}

export interface AttachedFile {
  name: string;
  size: number;
  type: string;
  content: string; // Base64 encoded content
}
