import ballerina/time;
public type User record {|
    string id;
    string username;
    string email;
    string passwordHash;
    string? displayName;
    time:Utc createdAt;
    time:Utc updatedAt;
    boolean isActive;
    string[] roles;
|};

public type RegisterRequest record {|
    string username;
    string email;
    string password;
    string? displayName;
|};

public type LoginRequest record {|
    string username;
    string password;
|};

public type AuthResponse record {|
    string accessToken;
    string refreshToken;
    int expiresIn;
    UserPublic user;
|};

public type UserPublic record {|
    string id;
    string username;
    string email;
    string? displayName;
    time:Utc createdAt;
    time:Utc updatedAt;
    string[] roles;
|};

public type RefreshTokenRequest record {|
    string refreshToken;
|};

public type JwtPayload record {|
    string sub;
    string username;
    string email;
    string[] roles;
    int iat;
    int exp;
|};

public type ForgotPasswordRequest record {|
    string email;
|};

public type ResetPasswordRequest record {|
    string token;
    string newPassword;
|};

public type PasswordResetToken record {|
    string _id?;
    string userId;
    string token;
    time:Utc expiresAt;
    boolean used;
|};