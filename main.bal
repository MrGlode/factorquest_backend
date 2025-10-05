import ballerina/http;
import ballerina/time;

@http:ServiceConfig {
    cors: {
        allowOrigins: cors_allowedOrigins,
        allowMethods: cors_allowedMethods,
        allowHeaders: cors_allowedHeaders,
        allowCredentials: cors_allowCredentials
    }
}

service on new http:Listener(server_port) {
    // Health check endpoint
    resource function get health() returns json {
        return {
            "status": "healthy",
            "service": "FactoQuest Backend",
            "version": "0.1.0",
            "environment": "development",
            "timestamp": time:utcNow()
        };
    }

    // API version info
    resource function get version() returns json {
        return {
            "version": "1.0.0",
            "apiPrefix": "/api/v1"
        };
    }
}