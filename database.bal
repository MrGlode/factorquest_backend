import ballerinax/mongodb;
import ballerina/log;
import ballerina/time;

mongodb:Client mongoClient = check initMongoClient();

public enum CollectionNames {
    USERS = "users",
    PLAYERS = "players",
    GAME_STATES = "game_states",
    INVENTORIES = "inventories",
    MACHINES = "machines",
    RESEARCHES = "researches",
    ACHIEVEMENTS = "achievements",
    LEADERBOARD = "leaderboard",
    TRANSACTIONS = "transactions",
    RESET_TOKENS = "reset_tokens"
};

function initMongoClient() returns mongodb:Client|error {
    string connectionUrl = string `mongodb://${db_host}:${db_port}`;
    
    mongodb:Client clientDb = check new ({
        connection: connectionUrl
    });
    
    log:printInfo("MongoDB client initialized successfully.");
    return clientDb;
}

public function getDatabase() returns mongodb:Database|error {
    return mongoClient->getDatabase(db_database);
}

public function getCollection(string collectionName) returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection(collectionName);
}

public function createPasswordResetToken(PasswordResetToken token) returns error? {
    mongodb:Collection tokens = check getCollection(RESET_TOKENS);
    
    map<json> tokenDoc = check token.cloneWithType();
    
    json|error insertResult = check tokens->insertOne(tokenDoc);

    if insertResult is error {
        log:printError("Failed to create password reset token", 'error = insertResult);
        return error("Error creating reset token");
    }
    log:printInfo("Password reset token created successfully for user: " + token.userId);
}

public function findPasswordResetToken(string token) returns PasswordResetToken|error {
    mongodb:Collection tokens = check getCollection(RESET_TOKENS);
    
    map<json> filter = { 
        "token": token 
    };

    PasswordResetToken|mongodb:DatabaseError|mongodb:ApplicationError? result = check tokens->findOne(filter);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error finding password reset token", result);
        return error("Error finding reset token");
    }
    
    if result is () {
        return error("Reset token not found");
    }
    
    return result;
}

public function markPasswordResetTokenUsed(string token) returns error? {
    mongodb:Collection tokens = check getCollection(RESET_TOKENS);
    
    map<json> filter = {
        "token": token
    };
    
    mongodb:Update update = {
        set: {
            "used": true
        }
    };
    
    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check tokens->updateOne(filter, update);
    
    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error marking token as used", updateResult);
        return error("Error updating token");
    }
    
    log:printInfo("Password reset token marked as used");
}

public function updatePasswordResetToken(string tokenId, PasswordResetToken updatedToken) returns error? {
    mongodb:Collection tokens = check getCollection(RESET_TOKENS);
    
    map<json> filter = {
        "id": tokenId
    };
    
    mongodb:Update update = {
        set: {
            "userId": updatedToken.userId,
            "token": updatedToken.token,
            "expiresAt": updatedToken.expiresAt,
            "used": updatedToken.used
        }
    };
    
    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check tokens->updateOne(filter, update);
    
    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating password reset token", updateResult);
        return error("Error updating token");
    }
    
    log:printInfo("Password reset token updated successfully");
}

public function cleanupExpiredTokens() returns int|error? {
    mongodb:Collection tokens = check getCollection(RESET_TOKENS);

    time:Utc now = time:utcNow();

    map<json> filter = {
        "$or": [
            { 
                "used": true
            },
            { 
                "expiresAt": { 
                    "$lt": now 
                } 
            }
        ]
    };

    json|error deleteResults = tokens->deleteMany(filter);

    if deleteResults is error {
        log:printError("Failed to clean up expired tokens", 'error = deleteResults);
        return error("Error cleaning up expired tokens");
    }

    map<json> resultMap = check deleteResults.cloneWithType();
    int deletedCount = check int:fromString(resultMap["deletedCount"].toString());
    log:printInfo("Cleaned up " + deletedCount.toString() + " expired tokens.");
    return deletedCount;
}

public function deleteUserResetTokens(string userId) returns error? {
    mongodb:Collection tokens = check getCollection(RESET_TOKENS);
    
    map<json> filter = { "userId": userId };

    json|error deleteResults = tokens->deleteMany(filter);

    if deleteResults is error {
        log:printError("Failed to delete reset tokens for user: " + userId, 'error = deleteResults);
        return error("Error deleting user reset tokens");
    }
    log:printInfo("Deleted reset tokens for user: " + userId);
}

public function countActiveTokensForUser(string userId) returns int|error {
    mongodb:Collection tokens = check getCollection(RESET_TOKENS);
    
    map<json> filter = {
        "userId": userId,
        "used": false
    };

    int|error countResult = tokens->countDocuments(filter);
    if countResult is error {
        log:printError("Failed to count active tokens for user: " + userId, 'error = countResult);
        return error("Error counting active tokens");
    }
    return countResult;
}

public function findUserByUsername(string username) returns User|error {
    mongodb:Collection users = check getCollection(USERS);
    
    map<json> filter = { 
        "username": username 
    };

    stream<User, error?> result = check users->find(filter);  

    User[] userList = check from User u in result select u;
    
    if userList.length() != 1 {
        return error("User not found");
    }

    return userList[0];
}

public function findUserByEmail(string email) returns User|error {
    mongodb:Collection users = check getCollection(USERS);
    
    map<json> filter = { 
        "email": email 
    };

    User|mongodb:DatabaseError|mongodb:ApplicationError? result = check users->findOne(filter);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error finding user by email", result);
        return error("Error finding user");
    }
    
    if result is () {
        return error("User not found");
    }
    
    return result;
}

public function findUserById(string userId) returns User|error {
    mongodb:Collection users = check getCollection(USERS);
    
    map<json> filter = { 
        "id": userId 
    };

    User|mongodb:DatabaseError|mongodb:ApplicationError? result = check users->findOne(filter);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error finding user by ID", result);
        return error("Error finding user");
    }
    
    if result is () {
        return error("User not found");
    }
    
    return result;
}

public function createUser(User user) returns User|error {
    mongodb:Collection users = check getCollection(USERS);

    check users->insertOne(user);

    User createdUser = check findUserByUsername(user.username);
    log:printInfo("User created successfully: " + createdUser.username);
    return createdUser;
}

public function updateUserPassword(string userId, string passwordHash) returns error? {
    mongodb:Collection users = check getCollection(USERS);

    map<json> filter = {
        "id": userId
    };

    time:Utc now = time:utcNow();

    mongodb:Update update = {
        set: {
            "passwordHash": passwordHash,
            "updatedAt": now
        }
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check users->updateOne(filter, update);

    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating user password", updateResult);
        return error("Error updating password");
    }

    log:printInfo("User password updated successfully for user ID: " + userId);
}

public function updateUserProfile(string userId, string? displayName) returns error? {
    mongodb:Collection users = check getCollection(USERS);

    map<json> filter = {
        "_id": userId
    };

    time:Utc now = time:utcNow();

    mongodb:Update update = {
        set: {
            "displayName": displayName,
            "updatedAt": now
        }
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check users->updateOne(filter, update);

    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating user profile", updateResult);
        return error("Error updating profile");
    }

    log:printInfo("User profile updated successfully for user ID: " + userId);
}

public function updateUserActiveStatus(string userId, boolean isActive) returns error? {
    mongodb:Collection users = check getCollection(USERS);
    map<json> filter = {
        "_id": userId
    };

    time:Utc now = time:utcNow();

    mongodb:Update update = {
        set: {
            "isActive": isActive,
            "updatedAt": now
        }
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check users->updateOne(filter, update);
    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating user active status", updateResult);
        return error("Error updating user status");
    }
    log:printInfo("User active status updated successfully for user ID: " + userId);
}

public function deleteUser(string userId) returns error? {
    return updateUserActiveStatus(userId, false);
}

public function countUsers() returns int|error {
    mongodb:Collection users = check getCollection(USERS);

    int|error countResult = users->countDocuments({});
    if countResult is error {
        log:printError("Failed to count users", 'error = countResult);
        return error("Error counting users");
    }
    return countResult;
}

public function listUsers(int skip = 0, int 'limit = 10) returns User[]|error {
    mongodb:Collection users = check getCollection(USERS);

    mongodb:FindOptions options = {
        sort: { "createdAt": -1 },
        skip: skip,
        'limit: 'limit
    };

    stream<User, error?>|mongodb:DatabaseError|mongodb:ApplicationError userStream = check users->find({}, options);

    if userStream is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error listing users", userStream);
        return error("Error listing users");
    }

    User[] userList = [];
    error? iterationError = userStream.forEach(function (User user) {
        userList.push(user);
    });

    if iterationError is error {
        log:printError("Error iterating user stream", iterationError);
        return error("Error processing user list");
    }
    return userList;
}

public function createPlayerProfile(string userId) returns PlayerProfile|error {
    mongodb:Collection players = check getCollection(PLAYERS);

    time:Utc now = time:utcNow();

    PlayerStats initialStats = {
        totalMoneyEarned: 0.0,
        totalMoneySpent: 0.0,
        totalPlayTime: 0,
        machinesBought: 0,
        resourcesProduced: 0,
        resourcesSold: 0,
        researchesCompleted: 0,
        specialOrdersCompleted: 0,
        highestMoney: 0.0,
        firstLoginDate: now,
        lastLoginDate: now,
        totalLogins: 1
    };

    PlayerProfile profile = {
        id: userId,
        userId: userId,
        level: 1,
        experience: 0,
        stats: initialStats,
        lastSavedAt: now
    };

    check players->insertOne(profile);

    PlayerProfile createdProfile = check findPlayerProfileByUserId(userId);
    log:printInfo("Player profile created successfully for user ID: " + userId);
    return createdProfile;
}

function findPlayerProfileByUserId(string userId) returns PlayerProfile|error {
    mongodb:Collection players = check getCollection(PLAYERS);

    map<json> filter = {
        "userId": userId
    };


    PlayerProfile|mongodb:DatabaseError|mongodb:ApplicationError? result = check players->findOne(filter);
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error finding player profile by user ID", result);
        return error("Error finding player profile");
    }
    if result is () {
        return error("Player profile not found");
    }
    return result;
}

public function updatePlayerStats(string userId, UpdatePlayerStatsRequest updates) returns error? {
    mongodb:Collection players = check getCollection(PLAYERS);
    
    map<json> filter = {
        "userId": userId
    };
    
    // Construire l'objet de mise à jour dynamiquement
    map<json> setFields = {};
    
    if updates.totalMoneyEarned is decimal {
        setFields["stats.totalMoneyEarned"] = updates.totalMoneyEarned;
    }
    if updates.totalMoneySpent is decimal {
        setFields["stats.totalMoneySpent"] = updates.totalMoneySpent;
    }
    if updates.totalPlayTime is int {
        setFields["stats.totalPlayTime"] = updates.totalPlayTime;
    }
    if updates.machinesBought is int {
        setFields["stats.machinesBought"] = updates.machinesBought;
    }
    if updates.resourcesProduced is int {
        setFields["stats.resourcesProduced"] = updates.resourcesProduced;
    }
    if updates.resourcesSold is int {
        setFields["stats.resourcesSold"] = updates.resourcesSold;
    }
    if updates.researchesCompleted is int {
        setFields["stats.researchesCompleted"] = updates.researchesCompleted;
    }
    if updates.specialOrdersCompleted is int {
        setFields["stats.specialOrdersCompleted"] = updates.specialOrdersCompleted;
    }
    if updates.highestMoney is decimal {
        setFields["stats.highestMoney"] = updates.highestMoney;
    }
    
    // Toujours mettre à jour lastSaveAt
    setFields["lastSaveAt"] = time:utcNow();
    
    mongodb:Update update = {
        set: setFields
    };
    
    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check players->updateOne(filter, update);
    
    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating player stats", updateResult);
        return error("Error updating stats");
    }
    
    if updateResult.modifiedCount == 0 {
        return error("Player profile not found or stats not updated");
    }
    
    log:printInfo("Player stats updated for user: " + userId);
}

public function incrementStat(string userId, string statName, int|decimal amount) returns error? {
    mongodb:Collection players = check getCollection(PLAYERS);
    
    map<json> filter = {
        "userId": userId
    };
    
    mongodb:Update update = {
        inc: {
            ["stats." + statName]: amount
        },
        set: {
            "lastSaveAt": time:utcNow()
        }
    };
    
    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check players->updateOne(filter, update);
    
    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error incrementing stat", updateResult);
        return error("Error incrementing stat");
    }
    
    log:printInfo("Stat incremented: " + statName + " for user: " + userId);
}

public function updateLevelAndExperience(string userId, int level, int experience) returns error? {
    mongodb:Collection players = check getCollection(PLAYERS);

    map<json> filter = {
        "userId": userId
    };
    
    mongodb:Update update = {
        set: {
            "level": level,
            "experience": experience,
            "lastSaveAt": time:utcNow()
        }
    };
    
    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check players->updateOne(filter, update);
    
    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error updating level/experience", updateResult);
        return error("Error updating level/experience");
    }
    
    log:printInfo("Level/Experience updated for user: " + userId);
}

public function recordLogin(string userId) returns error? {
    mongodb:Collection players = check getCollection(PLAYERS);

    map<json> filter = {
        "userId": userId
    };
    
    time:Utc now = time:utcNow();
    
    mongodb:Update update = {
        set: {
            "stats.lastLoginDate": now,
            "lastSaveAt": now
        },
        inc: {
            "stats.totalLogins": 1
        }
    };
    
    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError updateResult = check players->updateOne(filter, update);
    
    if updateResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error recording login", updateResult);
        return error("Error recording login");
    }
    
    log:printInfo("Login recorded for user: " + userId);
}

public function getPlayerProfilePublic(string userId) returns PlayerProfilePublic|error {
    PlayerProfile profile = check findPlayerProfileByUserId(userId);
    User user = check findUserById(userId);

    PlayerProfilePublic publicProfile = {
        id: profile.id,
        username: user.username,
        userId: userId,
        level: profile.level,
        experience: profile.experience,
        stats: profile.stats,
        lastSavedAt: profile.lastSavedAt
    };

    return publicProfile;
}

public function getTopPlayers(int 'limit = 10) returns PlayerProfilePublic[]|error {
    mongodb:Collection players = check getCollection(PLAYERS);

      map<json> filter = {};
    
    mongodb:FindOptions findOptions = {
        sort: {
            "level": -1,           // Trier par niveau décroissant
            "experience": -1       // Puis par expérience
        },
        'limit: 'limit
    };
    
    stream<PlayerProfile, error?>|mongodb:DatabaseError|mongodb:ApplicationError cursor = check players->find(filter, findOptions);
    
    if cursor is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error fetching top players", cursor);
        return error("Error fetching top players");
    }
    
    PlayerProfilePublic[] topPlayers = [];
    
    error? e = cursor.forEach(function(PlayerProfile profile) {
        // Récupérer le username depuis User
        User|error user = findUserById(profile.userId);

        if user is User {
            PlayerProfilePublic publicProfile = {
                id: profile.id,
                userId: profile.userId,
                username: user.username,
                level: profile.level,
                experience: profile.experience,
                stats: profile.stats,
                lastSavedAt: profile.lastSavedAt
            };
            topPlayers.push(publicProfile);
        }
    });
    
    if e is error {
        log:printError("Error processing top players", e);
        return error("Error processing top players");
    }
    
    return topPlayers;
}

public function countPlayers() returns int|error {
    mongodb:Collection players = check getCollection(PLAYERS);

    map<json> filter = {};

    int|mongodb:DatabaseError|mongodb:ApplicationError countResult = check players->countDocuments(filter);
    if countResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Failed to count players", 'error = countResult);
        return error("Error counting players");
    }
    return countResult;
}

public function deletePlayerProfile(string userId) returns error? {
    mongodb:Collection players = check getCollection(PLAYERS);
    
    map<json> filter = {
        "userId": userId
    };
    
    mongodb:DeleteResult|mongodb:DatabaseError|mongodb:ApplicationError deleteResult = check players->deleteOne(filter);
    
    if deleteResult is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error deleting player profile", deleteResult);
        return error("Error deleting player profile");
    }
    
    log:printInfo("Player profile deleted for user: " + userId);
}