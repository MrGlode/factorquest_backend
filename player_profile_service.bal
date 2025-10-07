import ballerina/log;
import ballerinax/mongodb;
import ballerina/time;
import ballerina/uuid;

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
        id: uuid:createType1AsString(),
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