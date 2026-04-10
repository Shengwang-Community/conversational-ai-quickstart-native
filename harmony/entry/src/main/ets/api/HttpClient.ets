import http from '@ohos.net.http';

export interface HttpResponseData {
  statusCode: number;
  body: string;
  headerText: string;
  url: string;
}

export class HttpClient {
  private static readonly REDIRECT_STATUS_CODES: Set<number> =
    new Set<number>([301, 302, 307, 308]);

  static async postJsonWithRedirects(
    url: string,
    headerJson: string,
    body: string,
    maxRedirects: number = 3
  ): Promise<HttpResponseData> {
    let currentUrl = url;

    for (let redirectCount = 0; redirectCount <= maxRedirects; redirectCount += 1) {
      const response = await HttpClient.postJson(currentUrl, headerJson, body);
      if (!HttpClient.REDIRECT_STATUS_CODES.has(response.statusCode)) {
        return response;
      }

      const nextLocation = HttpClient.extractHeaderValue(
        response.headerText,
        'location'
      );
      if (!nextLocation || nextLocation.length === 0) {
        return response;
      }

      currentUrl = nextLocation;
    }

    return HttpClient.postJson(currentUrl, headerJson, body);
  }

  static async postJson(
    url: string,
    headerJson: string,
    body: string
  ): Promise<HttpResponseData> {
    const request = http.createHttp();
    const headerObject = JSON.parse(headerJson) as Object;

    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headerObject,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 60000,
        connectTimeout: 60000
      });

      return {
        statusCode: Number(response.responseCode),
        body: HttpClient.stringifyBody(response.result),
        headerText: JSON.stringify(response.header),
        url
      };
    } finally {
      request.destroy();
    }
  }

  private static stringifyBody(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') {
      return result;
    }

    return JSON.stringify(result);
  }

  private static extractHeaderValue(headerText: string, headerName: string): string {
    const pattern = new RegExp(
      `"${headerName}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"`,
      'i'
    );
    const match = pattern.exec(headerText);
    if (!match || match.length < 2) {
      return '';
    }

    return HttpClient.decodeJsonString(match[1]);
  }

  private static decodeJsonString(value: string): string {
    try {
      return JSON.parse(`"${value.replace(/"/g, '\\"')}"`) as string;
    } catch (_) {
      return value;
    }
  }
}
