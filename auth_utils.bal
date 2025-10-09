import ballerina/crypto;
import ballerina/time;
import ballerina/jwt;
import ballerina/uuid;
import ballerina/random;
import ballerina/lang.array;

public isolated function hashPassword(string password) returns string|error {
    byte[] salt = check generateSalt();

    byte[] passwordBytes = password.toBytes();
    byte[] hash = crypto:hashSha512(passwordBytes, salt);

    string saltBase64 = salt.toBase64();
    string hashBase64 = hash.toBase64();


    return string `bcrypt:${security_bcryptRounds}:${saltBase64}:${hashBase64}`;
}

isolated function generateSalt() returns byte[]|error {
    byte[] salt = [];

    foreach int i in 0 ..< 16 {
        int randomByte = check random:createIntInRange(0, 255);
        salt.push(<byte>randomByte);
    }

    return salt;
}

public isolated function verifyPassword(string password, string hashedPassword) returns boolean|error {
    string[] parts = re `:`.split(hashedPassword);

    if parts.length() != 4 || parts[0] != "bcrypt" {
        return error("Invalid hashed password format");
    }

    string saltBase64 = parts[2];
    string hashBase64 = parts[3];

    byte[] salt = check array:fromBase64(saltBase64);

    byte[] passwordBytes = password.toBytes();
    byte[] computedHash = crypto:hashSha512(passwordBytes, salt);
    string computedHashBase64 = computedHash.toBase64();

    return secureCompare(computedHashBase64, hashBase64);
}

isolated function secureCompare(string a, string b) returns boolean {
    if a.length() != b.length() {
        return false;
    }

    byte[] bytesA = a.toBytes();
    byte[] bytesB = b.toBytes();
    
    int diff = 0;
    foreach int i in 0 ..< bytesA.length() {
        diff = diff | (bytesA[i] ^ bytesB[i]);
    }
    return diff == 0;
}

public isolated function generateAccessToken(User user) returns string|error {
    time:Utc currentTime = time:utcNow();
    decimal iat = currentTime[1];

    jwt:IssuerConfig issuerConfig = {
        username: user.username,
        issuer: jwt_issuer,
        audience: jwt_audience,
        expTime: iat + <decimal>jwt_expiresIn,
        signatureConfig: {
            algorithm: jwt:RS256,
            config: { 
                keyFile: jwt_privateKeyPath
            }
        },
        customClaims: {
            "sub": user.id,
            "email": user.email,
            "roles": user.roles
        }
    };

    return check jwt:issue(issuerConfig);
}

public isolated function generateRefreshToken(User user) returns string|error {
    time:Utc currentTime = time:utcNow();
    decimal iat = currentTime[1];

    jwt:IssuerConfig issuerConfig = {
        username: user.username,
        issuer: jwt_issuer,
        audience: jwt_audience,
        expTime: iat + <decimal>jwt_refreshExpiresIn,
        signatureConfig: {
            algorithm: jwt:RS256,
            config: { 
                keyFile: jwt_privateKeyPath
            }
        },
        customClaims: {
            "sub": user.id,
            "type": "refresh",
            "roles": user.roles,
            "email": user.email
        }
    };

    return check jwt:issue(issuerConfig);
}

public isolated function validateToken(string token) returns JwtPayload|error {
    jwt:ValidatorConfig validatorConfig = {
        issuer: jwt_issuer,
        audience: jwt_audience,
        signatureConfig: {
           certFile: jwt_publicKeyPath
        }
    };

    jwt:Payload payload = check jwt:validate(token, validatorConfig);
        
    // Extraire les valeurs avec gestion des erreurs (tous via accès par index)
    string sub = payload["sub"] is string ? <string>payload["sub"] : "";
    string username = payload["username"] is string ? <string>payload["username"] : "";
    string email = payload["email"] is string ? <string>payload["email"] : "";
    json[] roles = <json[]>payload["roles"];
    int iat = payload["iat"] is int ? <int>payload["iat"] : 0;
    int exp = payload["exp"] is int ? <int>payload["exp"] : 0;

    JwtPayload jwtPayload = {
        sub: sub,
        username: username,
        email: email,
        roles: roles,
        iat: iat,
        exp: exp
    };

    return jwtPayload;
}

public isolated function generatePasswordResetToken() returns string {
    return uuid:createType1AsString();
}

public isolated function toPublicUser(User user) returns UserPublic {
    return {
        id: user.id,
        username: user.username,
        email: user.email,
        roles: user.roles,
        createdAt: user.createdAt,
        displayName: user.displayName,
        updatedAt: user.updatedAt
    };
}

public isolated function isValidEmail(string email) returns boolean {
    string:RegExp emailRegex = re `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`;
    return email.matches(emailRegex);
}

public isolated function isValidPassword(string password) returns boolean {
    if password.length() < 8 {
        return false;
    }

    boolean hasLetter = false;
    boolean hasDigit = false;
    boolean hasSpecialChar = false;

    foreach int i in 0 ..< password.length() {
        string char = password.substring(i, i + 1);
        if char.matches(re `[a-zA-Z]`) {
            hasLetter = true;
        }
        if char.matches(re `[0-9]`) {
            hasDigit = true;
        }
        if char.matches(re `[\W_]`) {
            hasSpecialChar = true;
        }
    }

    return hasLetter && hasDigit && hasSpecialChar;
}