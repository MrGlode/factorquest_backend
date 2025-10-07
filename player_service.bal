import ballerina/log;
import ballerinax/mongodb;
import ballerina/time;

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