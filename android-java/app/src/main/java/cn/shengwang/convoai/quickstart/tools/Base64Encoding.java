package cn.shengwang.convoai.quickstart.tools;

import java.util.Base64;

/**
 * Base64Encoding utility class
 * <p>
 * Used to generate the HTTP Basic Authentication header required for Agora RESTful API calls.
 * Standard: RFC 7617
 */
public class Base64Encoding {

    /**
     * Generate Basic authorization header from customer key and secret.
     * <p>
     * Follows the standard HTTP Basic Authentication scheme: "Basic base64(key:secret)"
     *
     * @param customerKey RESTful API Key (Customer ID)
     * @param customerSecret RESTful API Secret (Customer Certificate)
     * @return Authorization header string in format "Basic <base64_encoded_credentials>"
     * @see <a href="https://docs.agora.io/en/video-calling/get-started/authentication-workflow#restful-api-authentication">Agora RESTful API Authentication</a>
     */
    public static String gen(String customerKey, String customerSecret) {
        // Concatenate customer ID and customer secret with a colon
        String plainCredentials = customerKey + ":" + customerSecret;
        
        // Encode the concatenated string with Base64
        // Note: Using java.util.Base64 (requires API level 26+ or desugaring)
        String base64Credentials = new String(Base64.getEncoder().encode(plainCredentials.getBytes()));

        // Create authorization header
        return "Basic " + base64Credentials;
    }
}
