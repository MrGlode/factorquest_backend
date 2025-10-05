import ballerina/time;

public type User record {|
    string _id;
    string username;
    string email;
    string passwordHash;
    string? displayName;
    time:Utc createdAt;
    time:Utc updatedAt;
    boolean isActive;
    string[] roles;
|};

public type PasswordResetToken record {|
    string _id;
    string userId;
    string token;
    time:Utc expiresAt;
    boolean used;
|};

type InsertOneResult record {|
    string insertedId;
|};

type UpdateResult record {|
    int matchedCount;
    int modifiedCount;
|};