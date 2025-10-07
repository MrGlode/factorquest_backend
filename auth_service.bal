import ballerina/log;
import ballerinax/mongodb;
import ballerina/time;

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