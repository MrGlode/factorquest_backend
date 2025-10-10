import ballerinax/mongodb;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;

// ============================================
// INITIALISATION AU DÉMARRAGE
// ============================================

public function initializeDefaultLaboratoryTypes() returns error? {
    mongodb:Collection labTypes = check getCollection(LABORATORY_TYPES);
    
    // Templates de laboratoires
    record {|
        LaboratoryType 'type;
        string name;
        decimal cost;
        decimal researchSpeed;
        int maxSimultaneousResearch;
        LaboratorySpecialization? specialization;
        string icon;
        string description;
    |}[] defaultTypes = [
        {
            'type: "basic",
            name: "Laboratoire de Base",
            cost: 5000.0d,
            researchSpeed: 1.0d,
            maxSimultaneousResearch: 1,
            specialization: "general",
            icon: "🧪",
            description: "Recherches fondamentales"
        },
        {
            'type: "advanced",
            name: "Laboratoire Avancé",
            cost: 15000.0d,
            researchSpeed: 1.5d,
            maxSimultaneousResearch: 2,
            specialization: "general",
            icon: "⚗️",
            description: "Recherches complexes, +50% vitesse"
        },
        {
            'type: "institute",
            name: "Institut de Recherche",
            cost: 50000.0d,
            researchSpeed: 2.0d,
            maxSimultaneousResearch: 3,
            specialization: "general",
            icon: "🔬",
            description: "Recherches avancées, +100% vitesse"
        },
        {
            'type: "mining",
            name: "Laboratoire Minier",
            cost: 8000.0d,
            researchSpeed: 1.3d,
            maxSimultaneousResearch: 1,
            specialization: "mine",
            icon: "⛏️",
            description: "Spécialisé dans les technologies minières"
        },
        {
            'type: "metallurgy",
            name: "Laboratoire de Métallurgie",
            cost: 12000.0d,
            researchSpeed: 1.3d,
            maxSimultaneousResearch: 1,
            specialization: "furnace",
            icon: "🔥",
            description: "Spécialisé dans les technologies de fonte"
        },
        {
            'type: "mechanical",
            name: "Laboratoire Mécanique",
            cost: 18000.0d,
            researchSpeed: 1.3d,
            maxSimultaneousResearch: 1,
            specialization: "assembler",
            icon: "⚙️",
            description: "Spécialisé dans les technologies d'assemblage"
        }
    ];
    
    foreach var labType in defaultTypes {
        int|error count = labTypes->countDocuments({ "type": labType.'type });
        if count is int && count == 0 {
            check labTypes->insertOne(labType);
            log:printInfo("Laboratory type created: " + labType.name);
        }
    }
    
    log:printInfo("✅ Default laboratory types initialized");
}

public function initializeDefaultResearches() returns error? {
    mongodb:Collection researches = check getCollection(RESEARCHES);
    
    // Catalogue de recherches
    Research[] defaultResearches = [
        // Recherches mines
        {
            id: "research_mining_speed_1",
            name: "Extraction Améliorée I",
            description: "Augmente la vitesse d'extraction de 15%",
            category: "mine",
            requirements: [
                { resourceId: "iron_plate", quantity: 20 },
                { resourceId: "copper_plate", quantity: 10 }
            ],
            duration: 60.0d,
            prerequisites: [],
            effects: [
                {
                    'type: "speed",
                    target: "mine",
                    value: 0.15d,
                    description: "Vitesse d'extraction +15%"
                }
            ],
            icon: "⛏️"
        },
        {
            id: "research_mining_speed_2",
            name: "Extraction Améliorée II",
            description: "Augmente la vitesse d'extraction de 25% supplémentaires",
            category: "mine",
            requirements: [
                { resourceId: "iron_plate", quantity: 50 },
                { resourceId: "copper_plate", quantity: 30 },
                { resourceId: "iron_gear", quantity: 10 }
            ],
            duration: 120.0d,
            prerequisites: ["research_mining_speed_1"],
            effects: [
                {
                    'type: "speed",
                    target: "mine",
                    value: 0.25d,
                    description: "Vitesse d'extraction +25%"
                }
            ],
            icon: "⛏️"
        },
        {
            id: "research_mining_output",
            name: "Extraction Efficace",
            description: "Double la production des mines",
            category: "mine",
            requirements: [
                { resourceId: "iron_plate", quantity: 100 },
                { resourceId: "copper_plate", quantity: 50 },
                { resourceId: "iron_gear", quantity: 30 }
            ],
            duration: 180.0d,
            prerequisites: ["research_mining_speed_2"],
            effects: [
                {
                    'type: "bonus_output",
                    target: "mine",
                    value: 1.0d,
                    description: "Production des mines doublée"
                }
            ],
            icon: "💎"
        },
        
        // Recherches fours
        {
            id: "research_smelting_speed_1",
            name: "Fonte Rapide I",
            description: "Augmente la vitesse de fonte de 20%",
            category: "furnace",
            requirements: [
                { resourceId: "iron_plate", quantity: 30 },
                { resourceId: "coal", quantity: 50 }
            ],
            duration: 90.0d,
            prerequisites: [],
            effects: [
                {
                    'type: "speed",
                    target: "furnace",
                    value: 0.20d,
                    description: "Vitesse de fonte +20%"
                }
            ],
            icon: "🔥"
        },
        {
            id: "research_smelting_efficiency",
            name: "Fonte Efficace",
            description: "Réduit la consommation de charbon de 30%",
            category: "furnace",
            requirements: [
                { resourceId: "iron_plate", quantity: 60 },
                { resourceId: "copper_plate", quantity: 40 },
                { resourceId: "coal", quantity: 100 }
            ],
            duration: 150.0d,
            prerequisites: ["research_smelting_speed_1"],
            effects: [
                {
                    'type: "efficiency",
                    target: "furnace",
                    value: 0.30d,
                    description: "Consommation de charbon -30%"
                }
            ],
            icon: "♻️"
        },
        
        // Recherches assembleurs
        {
            id: "research_assembly_speed_1",
            name: "Assemblage Automatisé I",
            description: "Augmente la vitesse d'assemblage de 25%",
            category: "assembler",
            requirements: [
                { resourceId: "iron_plate", quantity: 40 },
                { resourceId: "copper_plate", quantity: 30 },
                { resourceId: "iron_wire", quantity: 20 }
            ],
            duration: 120.0d,
            prerequisites: [],
            effects: [
                {
                    'type: "speed",
                    target: "assembler",
                    value: 0.25d,
                    description: "Vitesse d'assemblage +25%"
                }
            ],
            icon: "⚙️"
        },
        {
            id: "research_assembly_precision",
            name: "Assemblage de Précision",
            description: "Augmente la qualité et donne 10% de production bonus",
            category: "assembler",
            requirements: [
                { resourceId: "iron_gear", quantity: 50 },
                { resourceId: "copper_plate", quantity: 60 },
                { resourceId: "iron_wire", quantity: 40 }
            ],
            duration: 200.0d,
            prerequisites: ["research_assembly_speed_1"],
            effects: [
                {
                    'type: "bonus_output",
                    target: "assembler",
                    value: 0.10d,
                    description: "Production des assembleurs +10%"
                }
            ],
            icon: "✨"
        },
        
        // Recherches générales
        {
            id: "research_automation",
            name: "Automatisation Avancée",
            description: "Toutes les machines gagnent 10% de vitesse",
            category: "general",
            requirements: [
                { resourceId: "iron_plate", quantity: 100 },
                { resourceId: "copper_plate", quantity: 100 },
                { resourceId: "iron_gear", quantity: 50 },
                { resourceId: "iron_wire", quantity: 50 }
            ],
            duration: 300.0d,
            prerequisites: ["research_mining_speed_1", "research_smelting_speed_1", "research_assembly_speed_1"],
            effects: [
                {
                    'type: "speed",
                    target: "general",
                    value: 0.10d,
                    description: "Vitesse globale +10%"
                }
            ],
            icon: "🤖"
        }
    ];
    
    foreach Research research in defaultResearches {
        int|error count = researches->countDocuments({ "id": research.id });
        if count is int && count == 0 {
            check researches->insertOne(research);
            log:printInfo("Research created: " + research.name);
        }
    }
    
    log:printInfo("✅ Default researches initialized");
}

// ============================================
// HELPERS - LECTURE DEPUIS DB
// ============================================

function getLaboratoryTypeInfo(LaboratoryType labType) returns LaboratoryTypeInfo|error {
    mongodb:Collection labTypes = check getCollection(LABORATORY_TYPES);
    
    map<json> filter = { "type": labType };
    
    // Spécifier explicitement le type de retour
    LaboratoryTypeInfo|mongodb:DatabaseError|mongodb:ApplicationError? result = 
        check labTypes->findOne(filter);
    
    if result is mongodb:DatabaseError|mongodb:ApplicationError {
        log:printError("Error finding laboratory type", 'error = result);
        return error("Failed to retrieve laboratory type");
    }
    
    if result is () {
        return error("Laboratory type not found: " + labType);
    }
    
    return result;
}

// ============================================
// ACHETER UN LABORATOIRE
// ============================================

public function purchaseLaboratory(string userId, LaboratoryType labType) 
        returns PurchaseLaboratoryResponse|error {
    
    // 1. Récupérer les infos du type de laboratoire
    LaboratoryTypeInfo labInfo = check getLaboratoryTypeInfo(labType);
    
    // 2. Vérifier que le joueur a assez d'argent
    GameState gameState = check findGameStateByUserId(userId);
    if gameState.money < labInfo.cost {
        return error(string `Insufficient funds. Required: ${labInfo.cost}, Available: ${gameState.money}`);
    }
    
    // 3. Créer le laboratoire
    time:Utc now = time:utcNow();
    Laboratory laboratory = {
        id: uuid:createType1AsString(),
        userId: userId,
        'type: labInfo.'type,
        name: labInfo.name,
        cost: labInfo.cost,
        researchSpeed: labInfo.researchSpeed,
        maxSimultaneousResearch: labInfo.maxSimultaneousResearch,
        specialization: labInfo.specialization,
        purchaseTime: now
    };
    
    mongodb:Collection laboratories = check getCollection(LABORATORIES);
    check laboratories->insertOne(laboratory);
    
    // 4. Débiter l'argent
    error? debitResult = debitMoney(userId, labInfo.cost);
    if debitResult is error {
        // Rollback
        _ = check laboratories->deleteOne({ "id": laboratory.id });
        return error("Failed to debit money");
    }
    
    // 5. Mettre à jour les stats
    _ = check incrementStat(userId, "totalMoneySpent", labInfo.cost);
    
    // 6. Récupérer le nouveau solde
    GameState updatedGameState = check findGameStateByUserId(userId);
    
    log:printInfo(string `✅ Laboratory purchased: ${laboratory.name} for user ${userId}`);
    
    return {
        laboratory: laboratory,
        newBalance: updatedGameState.money
    };
}

// ============================================
// RÉCUPÉRER LES LABORATOIRES
// ============================================

public function getUserLaboratories(string userId) returns Laboratory[]|error {
    mongodb:Collection laboratories = check getCollection(LABORATORIES);
    
    map<json> filter = { "userId": userId };
    mongodb:FindOptions options = {
        sort: { "purchaseTime": 1 }
    };
    
    stream<Laboratory, error?> result = check laboratories->find(filter, options);
    
    Laboratory[] labs = [];
    error? e = result.forEach(function(Laboratory lab) {
        labs.push(lab);
    });
    
    if e is error {
        return error("Error processing laboratories");
    }
    
    return labs;
}

// ============================================
// RÉCUPÉRER LES RECHERCHES
// ============================================

public function getAllResearches() returns Research[]|error {
    mongodb:Collection researches = check getCollection(RESEARCHES);
    
    stream<Research, error?> result = check researches->find({});
    
    Research[] researchList = [];
    error? e = result.forEach(function(Research research) {
        researchList.push(research);
    });
    
    if e is error {
        return error("Error processing researches");
    }
    
    return researchList;
}

public function getResearchById(string researchId) returns Research|error {
    mongodb:Collection researches = check getCollection(RESEARCHES);
    
    map<json> filter = { "id": researchId };
    Research|error? result = check researches->findOne(filter);
    
    if result is error || result is () {
        return error("Research not found: " + researchId);
    }
    
    return result;
}

public function startResearch(string userId, string researchId, string laboratoryId) 
        returns StartResearchResponse|error {
    
    // 1. Vérifier que le laboratoire appartient au joueur
    mongodb:Collection laboratories = check getCollection(LABORATORIES);
    Laboratory|error? lab = check laboratories->findOne({ "id": laboratoryId, "userId": userId });
    
    if lab is error || lab is () {
        return error("Laboratory not found");
    }
    
    // 2. Vérifier que le laboratoire n'est pas plein
    int activeCount = check countActiveResearchesInLaboratory(userId, laboratoryId);
    if activeCount >= lab.maxSimultaneousResearch {
        return error(string `Laboratory is full. Max: ${lab.maxSimultaneousResearch}, Current: ${activeCount}`);
    }
    
    // 3. Récupérer la recherche
    Research research = check getResearchById(researchId);
    
    // 4. Vérifier que la recherche n'est pas déjà complétée
    boolean isCompleted = check isResearchCompleted(userId, researchId);
    if isCompleted {
        return error("Research already completed");
    }
    
    // 5. Vérifier que la recherche n'est pas déjà en cours
    boolean isInProgress = check isResearchInProgress(userId, researchId);
    if isInProgress {
        return error("Research already in progress");
    }
    
    // 6. Vérifier les prérequis
    foreach string prereqId in research.prerequisites {
        boolean prereqCompleted = check isResearchCompleted(userId, prereqId);
        if !prereqCompleted {
            return error(string `Prerequisite not completed: ${prereqId}`);
        }
    }
    
    // 7. Vérifier les ressources
    Inventory inventory = check findInventoryByUserId(userId);
    foreach ResearchRequirement req in research.requirements {
        int availableQuantity = 0;
        foreach InventoryItem item in inventory.items {
            if item.resourceId == req.resourceId {
                availableQuantity = item.quantity;
                break;
            }
        }
        
        if availableQuantity < req.quantity {
            return error(string `Insufficient ${req.resourceId}. Required: ${req.quantity}, Available: ${availableQuantity}`);
        }
    }
    
    // 8. Retirer les ressources
    foreach ResearchRequirement req in research.requirements {
        error? removeResult = removeResourceFromInventory(userId, req.resourceId, req.quantity);
        if removeResult is error {
            // TODO: Rollback
            return error("Failed to remove resources");
        }
    }
    
    // 9. Calculer la durée avec le bonus du laboratoire
    decimal adjustedDuration = research.duration / lab.researchSpeed;
    
    time:Utc now = time:utcNow();
    time:Utc estimatedEnd = time:utcAddSeconds(now, <decimal>adjustedDuration);
    
    // 10. Créer le progress
    ResearchProgress progress = {
        id: uuid:createType1AsString(),
        userId: userId,
        researchId: researchId,
        laboratoryId: laboratoryId,
        startTime: now,
        estimatedEndTime: estimatedEnd,
        progress: 0.0d
    };
    
    mongodb:Collection progressDb = check getCollection(RESEARCH_PROGRESS);
    check progressDb->insertOne(progress);
    
    log:printInfo(string `✅ Research started: ${research.name} for user ${userId} in lab ${laboratoryId}`);
    
    return {
        progress: progress,
        research: research
    };
}

public function getActiveResearches(string userId) returns ResearchProgress[]|error {
    mongodb:Collection progressDb = check getCollection(RESEARCH_PROGRESS);
    
    map<json> filter = { "userId": userId };
    mongodb:FindOptions options = {
        sort: { "startTime": -1 }
    };
    
    stream<ResearchProgress, error?> result = check progressDb->find(filter, options);
    
    ResearchProgress[] progresses = [];
    error? e = result.forEach(function(ResearchProgress progress) {
        progresses.push(progress);
    });
    
    if e is error {
        return error("Error processing research progress");
    }
    
    return progresses;
}

function countActiveResearchesInLaboratory(string userId, string laboratoryId) returns int|error {
    mongodb:Collection progressDb = check getCollection(RESEARCH_PROGRESS);
    
    map<json> filter = {
        "userId": userId,
        "laboratoryId": laboratoryId
    };
    
    return progressDb->countDocuments(filter);
}

function isResearchInProgress(string userId, string researchId) returns boolean|error {
    mongodb:Collection progressDb = check getCollection(RESEARCH_PROGRESS);
    
    int count = check progressDb->countDocuments({
        "userId": userId,
        "researchId": researchId
    });
    
    return count > 0;
}

public function completeResearch(string userId, string researchId) returns error? {
    mongodb:Collection progressDb = check getCollection(RESEARCH_PROGRESS);
    mongodb:Collection completedDb = check getCollection(COMPLETED_RESEARCHES);
    
    // Marquer comme complétée
    time:Utc now = time:utcNow();
    CompletedResearch completed = {
        id: uuid:createType1AsString(),
        userId: userId,
        researchId: researchId,
        completedAt: now
    };
    
    check completedDb->insertOne(completed);
    
    // Retirer du progress
    _ = check progressDb->deleteMany({
        "userId": userId,
        "researchId": researchId
    });
    
    // Mettre à jour les stats
    _ = check incrementStat(userId, "researchesCompleted", 1);
    
    log:printInfo(string `✅ Research completed: ${researchId} for user ${userId}`);
}

public function getCompletedResearches(string userId) returns CompletedResearch[]|error {
    mongodb:Collection completedDb = check getCollection(COMPLETED_RESEARCHES);
    
    map<json> filter = { "userId": userId };
    mongodb:FindOptions options = {
        sort: { "completedAt": -1 }
    };
    
    stream<CompletedResearch, error?> result = check completedDb->find(filter, options);
    
    CompletedResearch[] completed = [];
    error? e = result.forEach(function(CompletedResearch comp) {
        completed.push(comp);
    });
    
    if e is error {
        return error("Error processing completed researches");
    }
    
    return completed;
}

function isResearchCompleted(string userId, string researchId) returns boolean|error {
    mongodb:Collection completedDb = check getCollection(COMPLETED_RESEARCHES);
    
    int count = check completedDb->countDocuments({
        "userId": userId,
        "researchId": researchId
    });
    
    return count > 0;
}

public function getActiveEffects(string userId) returns ResearchEffect[]|error {
    // Récupérer toutes les recherches complétées
    CompletedResearch[] completed = check getCompletedResearches(userId);
    
    // Récupérer les effets de chaque recherche
    ResearchEffect[] allEffects = [];
    
    foreach CompletedResearch comp in completed {
        Research research = check getResearchById(comp.researchId);
        foreach ResearchEffect effect in research.effects {
            allEffects.push(effect);
        }
    }
    
    return allEffects;
}

public function calculateBonuses(string userId) returns map<decimal>|error {
    ResearchEffect[] effects = check getActiveEffects(userId);
    
    map<decimal> bonuses = {
        "mine_speed": 0.0d,
        "mine_efficiency": 0.0d,
        "mine_bonus_output": 0.0d,
        "furnace_speed": 0.0d,
        "furnace_efficiency": 0.0d,
        "furnace_bonus_output": 0.0d,
        "assembler_speed": 0.0d,
        "assembler_efficiency": 0.0d,
        "assembler_bonus_output": 0.0d,
        "general_speed": 0.0d,
        "general_efficiency": 0.0d
    };
    
    foreach ResearchEffect effect in effects {
        string targetStr = effect.target == "general" ? "general" : effect.target;
        string key = string `${targetStr}_${effect.'type}`;
        
        if bonuses.hasKey(key) {
            decimal currentValue = bonuses.get(key);
            bonuses[key] = currentValue + effect.value;
        }
    }
    
    return bonuses;
}