configurable int server_port = ?;
configurable string server_host = ?;
configurable string server_environment = ?;

configurable string[] cors_allowedOrigins = ?;
configurable string[] cors_allowedMethods = ?;
configurable string[] cors_allowedHeaders = ?;
configurable boolean cors_allowCredentials = ?;

configurable int security_bcryptRounds = ?;
configurable int security_maxLoginAttempts = ?;
configurable int security_lockoutDuration = ?;
configurable int game_startingMoney = ?;
configurable int game_defaultInventorySize = ?;

configurable string db_host = ?;
configurable int db_port = ?;
configurable string db_database = ?;

configurable string jwt_secret = ?;
configurable string jwt_issuer = ?;
configurable string jwt_audience = ?;
configurable int jwt_expiresIn = ?;
configurable int jwt_refreshExpiresIn = ?;