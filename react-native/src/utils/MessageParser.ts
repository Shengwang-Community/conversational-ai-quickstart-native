/**
 * Message Parser for RTC DataStream messages
 * Parses stream messages that may be split into multiple parts
 * Message format: messageId|partIndex|totalParts|base64Content
 * 
 * TODO: This is a placeholder implementation. Developers should refer to the documentation
 * and HarmonyOS MessageParser implementation for complete message parsing logic.
 * 
 * Reference: harmonyos/entry/src/main/ets/convoaiApi/MessageParser.ets
 */

// Type declarations for global objects available in React Native
declare const Buffer: {
  from(data: string, encoding: 'base64'): Uint8Array;
} | undefined;

declare const atob: ((data: string) => string) | undefined;

declare const TextDecoder: {
  new (encoding?: string): {
    decode(data: Uint8Array): string;
  };
} | undefined;

export class MessageParser {
  private messageMap: Map<string, Map<number, string>> = new Map();
  private maxMessageAge: number = 5 * 60 * 1000; // 5 minutes
  private lastAccessMap: Map<string, number> = new Map();
  private onErrorCallback?: (message: string) => void;

  setOnError(callback: (message: string) => void): void {
    this.onErrorCallback = callback;
  }

  /**
   * Parse stream message that may be split into multiple parts
   * Message format: messageId|partIndex|totalParts|base64Content
   * @param messageString Message string to parse
   * @returns Parsed object or null if parsing fails or message is incomplete
   */
  parseStreamMessage(messageString: string): Record<string, any> | null {
    try {
      // Clean up expired messages
      this.cleanExpiredMessages();

      const parts = messageString.split('|');
      if (parts.length !== 4) {
        const errorMsg = `[MessageParser] Invalid message format: expected 4 parts, got ${parts.length}, message: ${messageString.substring(0, 100)}`;
        if (this.onErrorCallback) {
          this.onErrorCallback(errorMsg);
        }
        return null;
      }

      const messageId = parts[0];
      const partIndex = parseInt(parts[1], 10);
      const totalParts = parseInt(parts[2], 10);
      const base64Content = parts[3];

      // Validate partIndex and totalParts
      if (isNaN(partIndex) || isNaN(totalParts)) {
        const errorMsg = `[MessageParser] Invalid partIndex or totalParts: partIndex=${parts[1]}, totalParts=${parts[2]}`;
        if (this.onErrorCallback) {
          this.onErrorCallback(errorMsg);
        }
        return null;
      }

      if (partIndex < 1 || partIndex > totalParts) {
        const errorMsg = `[MessageParser] partIndex out of range: partIndex=${partIndex}, totalParts=${totalParts}`;
        if (this.onErrorCallback) {
          this.onErrorCallback(errorMsg);
        }
        return null;
      }

      // Update last access time
      this.lastAccessMap.set(messageId, Date.now());

      // Store message parts
      let messageParts = this.messageMap.get(messageId);
      if (!messageParts) {
        messageParts = new Map<number, string>();
        this.messageMap.set(messageId, messageParts);
      }
      messageParts.set(partIndex, base64Content);

      // Log message part received
      if (this.onErrorCallback) {
        this.onErrorCallback(`[MessageParser] Received part ${partIndex}/${totalParts} for messageId=${messageId}, current parts: ${messageParts.size}`);
      }

      // Check if all parts are received
      if (messageParts.size === totalParts) {
        // All parts received, merge in order and decode
        let completeMessage = '';
        for (let i = 1; i <= totalParts; i++) {
          const part = messageParts.get(i);
          if (!part) {
            const errorMsg = `[MessageParser] Missing part ${i} for messageId=${messageId}`;
            if (this.onErrorCallback) {
              this.onErrorCallback(errorMsg);
            }
            return null;
          }
          completeMessage += part;
        }

        // Decode Base64 to string
        let jsonString: string;
        try {
          // React Native: Decode Base64 to UTF-8 string
          // Try using global Buffer (available in React Native via polyfill) or atob
          let decodedBytes: Uint8Array;
          
          if (typeof Buffer !== 'undefined') {
            // Use Buffer if available (React Native polyfill)
            const buffer = (Buffer as any).from(completeMessage, 'base64');
            decodedBytes = new Uint8Array(buffer);
          } else if (typeof atob !== 'undefined') {
            // Use atob if available (browser/WebView)
            const binaryString = atob(completeMessage);
            decodedBytes = new Uint8Array(binaryString.length);
            for (let i = 0; i < binaryString.length; i++) {
              decodedBytes[i] = binaryString.charCodeAt(i);
            }
          } else {
            throw new Error('Neither Buffer nor atob is available');
          }
          
          // Convert bytes to UTF-8 string
          // Use TextDecoder if available, otherwise manual conversion
          if (typeof TextDecoder !== 'undefined') {
            const decoder = new TextDecoder('utf-8');
            jsonString = decoder.decode(decodedBytes);
          } else {
            // Fallback: manual UTF-8 decoding (simplified)
            jsonString = String.fromCharCode.apply(null, Array.from(decodedBytes));
          }
          
          if (this.onErrorCallback) {
            this.onErrorCallback(`[MessageParser] Base64 decoded successfully, jsonString length: ${jsonString.length}`);
          }
        } catch (e) {
          const errorMessage = e instanceof Error ? e.message : 'Unknown error';
          const errorMsg = `[MessageParser] Failed to decode Base64: ${errorMessage}`;
          if (this.onErrorCallback) {
            this.onErrorCallback(errorMsg);
          }
          return null;
        }

        // Parse JSON
        let result: Record<string, any>;
        try {
          result = JSON.parse(jsonString);
          
          if (this.onErrorCallback) {
            this.onErrorCallback(`[MessageParser] JSON parsed successfully, message type: ${result['object'] || 'unknown'}`);
          }
        } catch (e) {
          const errorMessage = e instanceof Error ? e.message : 'Unknown error';
          const errorMsg = `[MessageParser] Failed to parse JSON: ${errorMessage}, jsonString: ${jsonString.substring(0, 200)}`;
          if (this.onErrorCallback) {
            this.onErrorCallback(errorMsg);
          }
          return null;
        }

        // Clean up processed message
        this.messageMap.delete(messageId);
        this.lastAccessMap.delete(messageId);

        return result;
      }

      // Message is incomplete, return null
      // This is normal for multi-part messages
      return null;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : 'Unknown error';
      const errorMsg = `[MessageParser] parseStreamMessage exception: ${errorMessage}`;
      if (this.onErrorCallback) {
        this.onErrorCallback(errorMsg);
      }
      return null;
    }
  }

  /**
   * Clean up expired messages
   */
  private cleanExpiredMessages(): void {
    const currentTime = Date.now();
    const expiredIds: string[] = [];

    this.lastAccessMap.forEach((lastAccess, messageId) => {
      if (currentTime - lastAccess > this.maxMessageAge) {
        expiredIds.push(messageId);
      }
    });

    expiredIds.forEach((id) => {
      this.messageMap.delete(id);
      this.lastAccessMap.delete(id);
    });
  }
}

