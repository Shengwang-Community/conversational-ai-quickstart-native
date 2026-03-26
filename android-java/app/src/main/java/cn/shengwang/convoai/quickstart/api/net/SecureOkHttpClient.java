package cn.shengwang.convoai.quickstart.api.net;

import java.security.KeyStore;
import java.util.Arrays;
import java.util.concurrent.TimeUnit;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;
import okhttp3.OkHttpClient;
import okhttp3.Protocol;

/**
 * SecureOkHttpClient - Creates secure OkHttpClient instances with SSL configuration
 */
public class SecureOkHttpClient {
    
    private static X509TrustManager createTrustManager() {
        try {
            TrustManagerFactory trustManagerFactory = TrustManagerFactory.getInstance(
                TrustManagerFactory.getDefaultAlgorithm()
            );
            trustManagerFactory.init((KeyStore) null);
            javax.net.ssl.TrustManager[] trustManagers = trustManagerFactory.getTrustManagers();
            if (trustManagers.length != 1 || !(trustManagers[0] instanceof X509TrustManager)) {
                throw new IllegalStateException("Unexpected default trust managers: " + Arrays.toString(trustManagers));
            }
            return (X509TrustManager) trustManagers[0];
        } catch (Exception e) {
            throw new RuntimeException("Failed to create trust manager", e);
        }
    }

    /**
     * Create OkHttpClient.Builder with secure SSL configuration
     * @return OkHttpClient.Builder instance
     */
    public static OkHttpClient.Builder create() {
        return create(30, 30, 30);
    }

    /**
     * Create OkHttpClient.Builder with secure SSL configuration and custom timeouts
     * @param readTimeoutSeconds Read timeout in seconds
     * @param writeTimeoutSeconds Write timeout in seconds
     * @param connectTimeoutSeconds Connect timeout in seconds
     * @return OkHttpClient.Builder instance
     */
    public static OkHttpClient.Builder create(
        long readTimeoutSeconds,
        long writeTimeoutSeconds,
        long connectTimeoutSeconds
    ) {
        try {
            X509TrustManager trustManager = createTrustManager();
            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(null, new javax.net.ssl.TrustManager[]{trustManager}, null);

            return new OkHttpClient.Builder()
                .writeTimeout(writeTimeoutSeconds, TimeUnit.SECONDS)
                .readTimeout(readTimeoutSeconds, TimeUnit.SECONDS)
                .connectTimeout(connectTimeoutSeconds, TimeUnit.SECONDS)
                .sslSocketFactory(sslContext.getSocketFactory(), trustManager)
                .hostnameVerifier((hostname, session) -> 
                    HttpsURLConnection.getDefaultHostnameVerifier().verify(hostname, session)
                )
                .protocols(Arrays.asList(Protocol.HTTP_2, Protocol.HTTP_1_1))
                .addInterceptor(new HttpLogger());
        } catch (Exception e) {
            throw new RuntimeException("Failed to create secure OkHttpClient", e);
        }
    }
}

