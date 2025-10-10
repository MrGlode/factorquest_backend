import ballerinax/mongodb;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerina/random;

public function initializeDefaultMarketBasePrices() returns error? {
    mongodb:Collection basePrices = check getCollection(MARKET_BASE_PRICES);

    MarketBasePrice[] defaultPrices = [
        { resourceId: "iron_ore", basePrice: 2.0d },
        { resourceId: "copper_ore", basePrice: 3.0d },
        { resourceId: "coal", basePrice: 1.0d },
        { resourceId: "iron_plate", basePrice: 8.0d },
        { resourceId: "copper_plate", basePrice: 10.0d },
        { resourceId: "iron_wire", basePrice: 15.0d },
        { resourceId: "iron_gear", basePrice: 25.0d }
    ];

    foreach MarketBasePrice price in defaultPrices {
        int|error count = basePrices->countDocuments({ "resourceId": price.resourceId });
        if count is int && count == 0 {
            check basePrices->insertOne(price);
            log:printInfo("Création du prix par défaut de la ressource: " + price.resourceId);
        }
    }

    log:printInfo("Initialisation des prix par défaut terminée.");
}

public function initializeDefaultMarketClients() returns error? {
    mongodb:Collection clients = check getCollection(MARKET_CLIENTS);

    MarketClient[] defaultClients = [
        { id: "client_noble_1", 'type: "noble", name: "Baron Von Steam" },
        { id: "client_noble_2", 'type: "noble", name: "Comtesse Gearwright" },
        { id: "client_noble_3", 'type: "noble", name: "Lord Cogsworth" },
        { id: "client_noble_4", 'type: "noble", name: "Duchesse Brassman" },
        { id: "client_factory_1", 'type: "factory", name: "Usine Mécanique" },
        { id: "client_factory_2", 'type: "factory", name: "Manufacture Vapor" },
        { id: "client_factory_3", 'type: "factory", name: "Forge Industrielle" },
        { id: "client_factory_4", 'type: "factory", name: "Atelier Royal" },
        { id: "client_gov_1", 'type: "government", name: "Ministère de l'Industrie" },
        { id: "client_gov_2", 'type: "government", name: "Arsenal Impérial" },
        { id: "client_gov_3", 'type: "government", name: "Bureau des Inventions" },
        { id: "client_merchant_1", 'type: "merchant", name: "Compagnie des Métaux" },
        { id: "client_merchant_2", 'type: "merchant", name: "Négoce Steam & Co" },
        { id: "client_merchant_3", 'type: "merchant", name: "Maison du Cuivre" }
    ];

    foreach MarketClient cli in defaultClients {
        int|error count = clients->countDocuments({ "id": cli.id });
        if count is int && count == 0 {
            check clients->insertOne(cli);
            log:printInfo("Création du client par défaut: " + cli.name);
        }
    }
    log:printInfo("Initialisation des clients par défaut terminée.");
}

function initializeDefaultMarketMultipliers() returns error? {
    mongodb:Collection multipliersDb = check getCollection(MARKET_CLIENTS_MULTIPLIERS);

    MarketClientMultiplier[] multipliers = [
        { 'type: "noble", multiplier: 1.5d },
        { 'type: "factory", multiplier: 1.2d },
        { 'type: "government", multiplier: 1.8d },
        { 'type: "merchant", multiplier: 1.0d }
    ];

    foreach MarketClientMultiplier multiplier in multipliers {
        int|error count = multipliersDb->countDocuments({ "type": multiplier.'type });
        if count is int && count == 0 {
            check multipliersDb->insertOne(multiplier);
            log:printInfo("Création du multiplicateur par défaut pour le type: " + multiplier.'type);
        }
    }

    log:printInfo("Initialisation des multiplicateurs par défaut terminée.");
}

function getMarketBasePrices() returns map<decimal>|error {
    mongodb:Collection basePrices = check getCollection(MARKET_BASE_PRICES);
    
    stream<MarketBasePrice, error?> result = check basePrices->find({});
    
    map<decimal> prices = {};
    error? e = result.forEach(function(MarketBasePrice price) {
        prices[price.resourceId] = price.basePrice;
    });
    
    if e is error {
        return error("Failed to load base prices");
    }
    
    return prices;
}

function getMarketClientsByType(ClientType clientType) returns string[]|error {
    mongodb:Collection clients = check getCollection(MARKET_CLIENTS);
    
    map<json> filter = { "type": clientType };
    stream<MarketClient, error?> result = check clients->find(filter);
    
    string[] names = [];
    error? e = result.forEach(function(MarketClient cli) {
        names.push(cli.name);
    });
    
    if e is error {
        return error("Failed to load clients");
    }
    
    return names;
}

function getMarketMultiplier(ClientType clientType) returns decimal|error {
    mongodb:Collection multipliers = check getCollection(MARKET_CLIENTS_MULTIPLIERS);
    
    map<json> filter = { "type": clientType };
    MarketClientMultiplier|error? result = check multipliers->findOne(filter);
    
    if result is error || result is () {
        return 1.0d; // Valeur par défaut
    }
    
    return result.multiplier;
}

public function initializeMarketPrices(string userId) returns error? {
    mongodb:Collection marketPrices = check getCollection(MARKET_PRICES);

    // Vérifier si déjà initialisé pour cet utilisateur
    int|error count = marketPrices->countDocuments({"userId": userId});
    if count is int && count > 0 {
        log:printInfo("Market prices already initialized for user: " + userId);
        return;
    }
    
    // Récupérer les prix de base depuis la DB
    map<decimal> basePrices = check getMarketBasePrices();
    
    time:Utc now = time:utcNow();
    
    // Créer les prix pour chaque ressource
    foreach string resourceId in basePrices.keys() {
        decimal basePrice = basePrices.get(resourceId);
        
        // Demande initiale aléatoire entre 0.5 et 1.0
        decimal initialDemand = 0.5d + (<decimal>random:createDecimal() * 0.5d);
        
        MarketPrice price = {
            userId: userId,
            resourceId: resourceId,
            basePrice: basePrice,
            currentPrice: basePrice,
            demand: initialDemand,
            lastSold: now,
            updatedAt: now
        };
        
        check marketPrices->insertOne(price);
    }

    log:printInfo("Market prices initialized for user: " + userId);
}

public function getMarketPrices(string userId) returns MarketPrice[]|error {
    mongodb:Collection marketPrices = check getCollection(MARKET_PRICES);
    
    map<json> filter = {"userId": userId};
    
    stream<MarketPrice, error?>|mongodb:DatabaseError|mongodb:ApplicationError result = 
        check marketPrices->find(filter);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error fetching market prices", 'error = result);
        return error("Failed to fetch market prices");
    }
    
    MarketPrice[] prices = [];
    error? e = result.forEach(function(MarketPrice price) {
        prices.push(price);
    });
    
    if e is error {
        return error("Error processing market prices");
    }
    
    return prices;
}

public function getMarketPriceByResource(string userId, string resourceId) returns MarketPrice|error {
    mongodb:Collection marketPrices = check getCollection(MARKET_PRICES);
    
    map<json> filter = {
        "userId": userId,
        "resourceId": resourceId
    };
    
    MarketPrice|mongodb:DatabaseError|mongodb:ApplicationError? result = 
        check marketPrices->findOne(filter);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error fetching market price", 'error = result);
        return error("Failed to fetch market price");
    }
    
    if result is () {
        return error("Market price not found for resource: " + resourceId);
    }
    
    return result;
}

public function updateMarketPrices(string userId) returns error? {
    mongodb:Collection marketPrices = check getCollection(MARKET_PRICES);
    
    MarketPrice[] prices = check getMarketPrices(userId);
    time:Utc now = time:utcNow();
    
    foreach MarketPrice price in prices {
        // Fluctuation aléatoire de la demande (-0.1 à +0.1)
        decimal demandChange = (<decimal>random:createDecimal() - 0.5d) * 0.2d;
        decimal newDemand = price.demand + demandChange;
        
        // Limiter entre 0.1 et 1.0
        if newDemand < 0.1d {
            newDemand = 0.1d;
        }
        if newDemand > 1.0d {
            newDemand = 1.0d;
        }
        
        // Facteur temps : baisse si pas vendu depuis longtemps
        decimal secondsSinceLastSold = <decimal>time:utcDiffSeconds(now, price.lastSold);
        decimal hoursSinceLastSold = secondsSinceLastSold / 3600.0d;
        decimal timeFactor = 1.0d - (hoursSinceLastSold / 100.0d);
        if timeFactor < 0.8d {
            timeFactor = 0.8d;
        }
        
        // Calculer le nouveau prix
        decimal newPrice = price.basePrice * newDemand * timeFactor;
        
        // Mettre à jour en DB
        map<json> filter = {
            "userId": userId,
            "resourceId": price.resourceId
        };
        
        mongodb:Update update = {
            set: {
                "demand": newDemand,
                "currentPrice": newPrice,
                "updatedAt": now
            }
        };
        
        _ = check marketPrices->updateOne(filter, update);
    }
    
    log:printInfo("Market prices updated for user: " + userId);
}

public function sellResource(string userId, string resourceId, int quantity) 
        returns SellResourceResponse|error {
    
    // 1. Vérifier que la ressource existe dans l'inventaire
    Inventory inventory = check findInventoryByUserId(userId);
    
    int availableQuantity = 0;
    foreach InventoryItem item in inventory.items {
        if item.resourceId == resourceId {
            availableQuantity = item.quantity;
            break;
        }
    }
    
    if availableQuantity < quantity {
        return error(string `Insufficient resources. Available: ${availableQuantity}, Required: ${quantity}`);
    }
    
    // 2. Récupérer le prix actuel
    MarketPrice price = check getMarketPriceByResource(userId, resourceId);
    
    // 3. Calculer les gains
    decimal earnings = price.currentPrice * <decimal>quantity;
    
    // 4. Retirer les ressources de l'inventaire
    error? removeResult = removeResourceFromInventory(userId, resourceId, quantity);
    if removeResult is error {
        return error("Failed to remove resources from inventory");
    }
    
    // 5. Créditer l'argent
    error? creditResult = creditMoney(userId, earnings);
    if creditResult is error {
        // Rollback : remettre les ressources
        _ = check addResourceToInventory(userId, resourceId, quantity);
        return error("Failed to credit money");
    }
    
    // 6. Mettre à jour le prix du marché
    time:Utc now = time:utcNow();
    decimal newDemand = price.demand - (<decimal>quantity * 0.01d);
    if newDemand < 0.1d {
        newDemand = 0.1d;
    }
    
    mongodb:Collection marketPrices = check getCollection(MARKET_PRICES);
    map<json> filter = {
        "userId": userId,
        "resourceId": resourceId
    };
    
    mongodb:Update update = {
        set: {
            "demand": newDemand,
            "lastSold": now,
            "updatedAt": now
        }
    };
    
    _ = check marketPrices->updateOne(filter, update);
    
    // 7. Créer la transaction
    Transaction tx = {
        id: uuid:createType1AsString(),
        userId: userId,
        resourceId: resourceId,
        quantity: quantity,
        unitPrice: price.currentPrice,
        totalValue: earnings,
        timestamp: now,
        'type: "market",
        orderId: ()
    };
    
    mongodb:Collection transactions = check getCollection(TRANSACTIONS);
    check transactions->insertOne(tx);
    
    // 8. Mettre à jour les stats
    _ = check incrementStat(userId, "resourcesSold", quantity);
    _ = check incrementStat(userId, "totalMoneyEarned", earnings);
    
    // 9. Récupérer le nouveau solde
    GameState gameState = check findGameStateByUserId(userId);
    
    // 10. Récupérer le prix mis à jour
    MarketPrice updatedPrice = check getMarketPriceByResource(userId, resourceId);

    log:printInfo(string `Sold ${quantity} ${resourceId} for ${earnings} credits (user: ${userId})`);

    return {
        earnings: earnings,
        newBalance: gameState.money,
        updatedPrice: updatedPrice,
        'transaction: tx
    };
}

public function generateSpecialOrder(string userId) returns SpecialOrder|error {
    // 1. Choisir un type de client aléatoirement
    ClientType[] clientTypes = ["noble", "factory", "government", "merchant"];
    int clientTypeIndex = check random:createIntInRange(0, clientTypes.length());
    ClientType clientType = clientTypes[clientTypeIndex];
    
    // 2. Choisir un nom de client depuis la DB
    string[] names = check getMarketClientsByType(clientType);
    if names.length() == 0 {
        return error("No clients found for type: " + clientType);
    }
    int nameIndex = check random:createIntInRange(0, names.length());
    string clientName = names[nameIndex];
    
    // 3. Récupérer les prix de base depuis la DB
    map<decimal> basePrices = check getMarketBasePrices();
    string[] resourceIds = basePrices.keys();
    
    // 4. Générer 1 à 3 exigences de ressources
    int numRequirements = check random:createIntInRange(1, 4); // 1 à 3
    OrderRequirement[] requirements = [];
    
    foreach int i in 0 ..< numRequirements {
        int resourceIndex = check random:createIntInRange(0, resourceIds.length());
        string resourceId = resourceIds[resourceIndex];
        
        // Vérifier que la ressource n'est pas déjà dans les requirements
        boolean alreadyExists = false;
        foreach OrderRequirement req in requirements {
            if req.resourceId == resourceId {
                alreadyExists = true;
                break;
            }
        }
        
        if !alreadyExists {
            int quantity = check random:createIntInRange(10, 61); // 10 à 60
            requirements.push({
                resourceId: resourceId,
                quantity: quantity
            });
        }
    }
    
    // 5. Calculer la récompense
    decimal baseReward = 0.0d;
    foreach OrderRequirement req in requirements {
        decimal basePrice = basePrices.get(req.resourceId);
        baseReward += basePrice * <decimal>req.quantity;
    }
    
    // 6. Récupérer le multiplicateur depuis la DB
    decimal multiplier = check getMarketMultiplier(clientType);
    decimal reward = baseReward * multiplier;
    decimal bonus = reward * 0.2d; // 20% de bonus si livré à temps
    
    // 7. Générer une description
    string description = generateOrderDescription(clientType, clientName);
    
    // 8. Deadline : 2 heures à partir de maintenant
    time:Utc now = time:utcNow();
    time:Utc deadline = time:utcAddSeconds(now, 7200); // 2 heures
    
    // 9. Créer la commande
    SpecialOrder 'order = {
        id: uuid:createType1AsString(),
        userId: userId,
        clientName: clientName,
        clientType: clientType,
        requirements: requirements,
        reward: reward,
        bonus: bonus,
        deadline: deadline,
        description: description,
        isCompleted: false,
        isExpired: false,
        createdAt: now,
        completedAt: ()
    };
    
    // 10. Sauvegarder en DB
    mongodb:Collection orders = check getCollection(SPECIAL_ORDERS);
    check orders->insertOne('order);
    
    log:printInfo(string `Generated special order ${'order.id} for user ${userId}`);
    
    return 'order;
}

function generateOrderDescription(ClientType clientType, string clientName) returns string {
    match clientType {
        "noble" => {
            return string `${clientName} souhaite équiper son domaine avec ces ressources de qualité.`;
        }
        "factory" => {
            return string `${clientName} a besoin de ces matériaux pour sa production.`;
        }
        "government" => {
            return string `${clientName} requiert ces ressources pour un projet d'État.`;
        }
        "merchant" => {
            return string `${clientName} propose un contrat commercial avantageux.`;
        }
    }
    return "Commande spéciale";
}

public function getActiveSpecialOrders(string userId) returns SpecialOrder[]|error {
    mongodb:Collection orders = check getCollection(SPECIAL_ORDERS);
    
    time:Utc now = time:utcNow();
    
    map<json> filter = {
        "userId": userId,
        "isCompleted": false,
        "deadline": { \$gt: now}
    };
    
    mongodb:FindOptions options = {
        sort: {"createdAt": -1}
    };
    
    stream<SpecialOrder, error?>|mongodb:DatabaseError|mongodb:ApplicationError result = 
        check orders->find(filter, options);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        return error("Failed to fetch special orders");
    }
    
    SpecialOrder[] orderList = [];
    error? e = result.forEach(function(SpecialOrder 'order) {
        orderList.push('order);
    });
    
    if e is error {
        return error("Error processing special orders");
    }
    
    return orderList;
}

public function fulfillSpecialOrder(string userId, string orderId) 
        returns FulfillOrderResponse|error {
    
    // 1. Récupérer la commande
    mongodb:Collection orders = check getCollection(SPECIAL_ORDERS);
    
    map<json> filter = {
        "id": orderId,
        "userId": userId
    };
    
    SpecialOrder|mongodb:DatabaseError|mongodb:ApplicationError? orderResult = 
        check orders->findOne(filter);
    
    if orderResult is mongodb:DatabaseError|mongodb:ApplicationError {
        return error("Failed to fetch order");
    }
    
    if orderResult is () {
        return error("Order not found");
    }
    
    SpecialOrder 'order = orderResult;
    
    // 2. Vérifier que la commande n'est pas déjà complétée
    if 'order.isCompleted {
        return {
            success: false,
            message: "Order already completed",
            reward: 0.0d,
            newBalance: 0.0d,
            'transaction: ()
        };
    }
    
    // 3. Vérifier que la commande n'est pas expirée
    time:Utc now = time:utcNow();
    decimal secondsRemaining = time:utcDiffSeconds('order.deadline, now);
    boolean isExpired = secondsRemaining < 0.0d;  // Si deadline - now < 0, c'est expiré
    if isExpired {
        return {
            success: false,
            message: "Order expired",
            reward: 0.0d,
            newBalance: 0.0d,
            'transaction: ()
        };
    }
    
    // 4. Vérifier que le joueur a toutes les ressources
    Inventory inventory = check findInventoryByUserId(userId);
    
    foreach OrderRequirement req in 'order.requirements {
        int availableQuantity = 0;
        foreach InventoryItem item in inventory.items {
            if item.resourceId == req.resourceId {
                availableQuantity = item.quantity;
                break;
            }
        }
        
        if availableQuantity < req.quantity {
            return {
                success: false,
                message: string `Insufficient ${req.resourceId}. Required: ${req.quantity}, Available: ${availableQuantity}`,
                reward: 0.0d,
                newBalance: 0.0d,
                'transaction: ()
            };
        }
    }
    
    // 5. Retirer toutes les ressources
    foreach OrderRequirement req in 'order.requirements {
        error? removeResult = removeResourceFromInventory(userId, req.resourceId, req.quantity);
        if removeResult is error {
            // TODO: Rollback complet si échec
            return error("Failed to remove resources");
        }
    }
    
    // 6. Calculer la récompense (avec bonus si livré à temps)
    decimal secondsUntilDeadline = time:utcDiffSeconds('order.deadline, now);
    boolean isOnTime = secondsUntilDeadline > 0.0d;  // Si deadline - now > 0, c'est à temps
    decimal totalReward = isOnTime ? ('order.reward + 'order.bonus) : 'order.reward;

    // 7. Créditer l'argent
    error? creditResult = creditMoney(userId, totalReward);
    if creditResult is error {
        // TODO: Rollback
        return error("Failed to credit money");
    }
    
    // 8. Marquer la commande comme complétée
    mongodb:Update update = {
        set: {
            "isCompleted": true,
            "completedAt": now
        }
    };
    
    _ = check orders->updateOne(filter, update);
    
    // 9. Créer la transaction
    Transaction 'transaction = {
        id: uuid:createType1AsString(),
        userId: userId,
        resourceId: "special_order",
        quantity: 1,
        unitPrice: totalReward,
        totalValue: totalReward,
        timestamp: now,
        'type: "order",
        orderId: orderId
    };
    
    mongodb:Collection transactions = check getCollection(TRANSACTIONS);
    check transactions->insertOne('transaction);
    
    // 10. Mettre à jour les stats
    _ = check incrementStat(userId, "specialOrdersCompleted", 1);
    _ = check incrementStat(userId, "totalMoneyEarned", totalReward);

    // 11. Générer une nouvelle commande
    _ = check generateSpecialOrder(userId);
    
    // 12. Récupérer le nouveau solde
    GameState gameState = check findGameStateByUserId(userId);
    
    string message = isOnTime ? 
        "Commande livrée à temps ! Bonus inclus !" : 
        "Commande livrée (en retard, pas de bonus)";
    
    log:printInfo(string `Fulfilled order ${orderId} for user ${userId} (reward: ${totalReward})`);
    
    return {
        success: true,
        message: message,
        reward: totalReward,
        newBalance: gameState.money,
        'transaction: 'transaction
    };
}

public function getTransactions(string userId, int 'limit = 50) returns Transaction[]|error {
    mongodb:Collection transactions = check getCollection(TRANSACTIONS);
    
    map<json> filter = {"userId": userId};
    
    mongodb:FindOptions options = {
        sort: {"timestamp": -1},
        'limit: 'limit
    };
    
    stream<Transaction, error?>|mongodb:DatabaseError|mongodb:ApplicationError result = 
        check transactions->find(filter, options);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        return error("Failed to fetch transactions");
    }
    
    Transaction[] transactionList = [];
    error? e = result.forEach(function(Transaction txn) {
        transactionList.push(txn);
    });
    
    if e is error {
        return error("Error processing transactions");
    }
    
    return transactionList;
}

function creditMoney(string userId, decimal amount) returns error? {
    mongodb:Collection gameStates = check getCollection(GAME_STATES);

    map<json> filter = {"userId": userId};

    mongodb:Update update = {
        inc: {"money": amount},
        set: {"lastSavedTime": time:utcNow()}
    };

    mongodb:UpdateResult|mongodb:DatabaseError|mongodb:ApplicationError result = 
        check gameStates->updateOne(filter, update);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error crediting money for user: " + userId, 'error = result);
        return error("Failed to credit money");
    }
    
    if result.matchedCount == 0 {
        return error("Game state not found for user");
    }

    log:printInfo("Credited " + amount.toString() + " to user: " + userId);
}

function removeResourceFromInventory(string userId, string resourceId, int quantity) returns error? {
    Inventory inventory = check findInventoryByUserId(userId);
    
    // Trouver et mettre à jour la quantité
    boolean found = false;
    foreach int i in 0 ..< inventory.items.length() {
        if inventory.items[i].resourceId == resourceId {
            int newQuantity = inventory.items[i].quantity - quantity;
            if newQuantity < 0 {
                return error("Insufficient resources");
            }
            inventory.items[i] = {
                resourceId: resourceId,
                quantity: newQuantity
            };
            found = true;
            break;
        }
    }
    
    if !found {
        return error("Resource not found in inventory");
    }
    
    // Mettre à jour en DB
    return updateInventory(userId, inventory.items);
}

function addResourceToInventory(string userId, string resourceId, int quantity) returns error? {
    Inventory inventory = check findInventoryByUserId(userId);
    
    // Trouver et mettre à jour la quantité
    boolean found = false;
    foreach int i in 0 ..< inventory.items.length() {
        if inventory.items[i].resourceId == resourceId {
            inventory.items[i] = {
                resourceId: resourceId,
                quantity: inventory.items[i].quantity + quantity
            };
            found = true;
            break;
        }
    }
    
    // Si pas trouvé, ajouter
    if !found {
        inventory.items.push({
            resourceId: resourceId,
            quantity: quantity
        });
    }
    
    // Mettre à jour en DB
    return updateInventory(userId, inventory.items);
}