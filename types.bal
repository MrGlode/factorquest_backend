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
    json[] roles;
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
    string id?;
    string userId;
    string token;
    time:Utc expiresAt;
    boolean used;
|};

public type PlayerStats record {|
    decimal totalMoneyEarned;
    decimal totalMoneySpent;
    int totalPlayTime;
    int machinesBought;
    int resourcesProduced;
    int resourcesSold;
    int researchesCompleted;
    int specialOrdersCompleted;
    decimal highestMoney;
    time:Utc firstLoginDate;
    time:Utc lastLoginDate;
    int totalLogins;
|};

public type PlayerProfile record {|
    string id;
    string userId;
    int level;
    int experience;
    PlayerStats stats;
    time:Utc lastSavedAt;
|};

public type CreatePlayerProfileRequest record {|
    string userId;
|};

public type UpdatePlayerStatsRequest record {|
    decimal? totalMoneyEarned;
    decimal? totalMoneySpent;
    int? totalPlayTime;
    int? machinesBought;
    int? resourcesProduced;
    int? resourcesSold;
    int? researchesCompleted;
    int? specialOrdersCompleted;
    decimal? highestMoney;
|};

public type PlayerProfilePublic record {|
    string id;
    string username;
    string userId;
    int level;
    int experience;
    PlayerStats stats;
    time:Utc lastSavedAt;
|};

public type Resource record {|
    string id;
    string name;
    string icon;
|};

public type MachineType "mine"|"furnace"|"assembler";

public type RecipeIO record {|
    string resourceId;
    int quantity;
|};

public type Recipe record {|
    string id;
    string name;
    RecipeIO[] inputs;
    RecipeIO[] outputs;
    decimal duration;
    MachineType machineType;
|};

public type GameState record {|
    string id;
    string userId;
    decimal money;
    time:Utc lastSavedTime;
    int totalPlayTime;
|};

public type InventoryItem record {|
    string resourceId;
    int quantity;
|};

public type Inventory record {|
    string id;
    string userId;
    InventoryItem[] items;
    time:Utc lastUpdated;
|};

public type Machine record {|
    string id;
    string userId;
    MachineType 'type;
    string name;
    decimal cost;
    string? selectedRecipeId;
    time:Utc lastProductionTime;
    decimal pauseProgress;
    boolean isActive;
    time:Utc createdAt;
|};

public type CreateGameStateRequest record {|
    string userId;
    decimal? initialMoney;
|};

public type UpdateGameStateRequest record {|
    decimal? money;
    int? totalPlayTime;
|};

public type UpdateInveintoryRequest record {|
    string resourceId;
    int quantity;
|};

public type CreateMachineRequest record {|
    MachineType 'type;
|};

public type UpdateMachineRequest record {|
    time:Utc? lastProductionTime;
    string? selectedRecipeId;
    decimal? pauseProgress;
    boolean? isActive;
|};

public type GameStateResponse record {|
    GameState state;
    Inventory inventory;
    Machine[] machines;
|};

public type ClientType "noble"|"factory"|"government"|"merchant";

public type TransactionType "market"|"order";

public type MarketPrice record {|
    string id?;
    string userId;
    string resourceId;
    decimal basePrice;
    decimal currentPrice;
    decimal demand;
    time:Utc lastSold;
    time:Utc updatedAt;
|};

public type OrderRequirement record {|
    string resourceId;
    int quantity;
|};

public type SpecialOrder record {|
    string id;
    string userId;
    string clientName;
    ClientType clientType;
    OrderRequirement[] requirements;
    decimal reward;
    decimal bonus;
    time:Utc deadline;
    string description;
    boolean isCompleted;
    boolean isExpired;
    time:Utc createdAt;
    time:Utc? completedAt;
|};

public type Transaction record {|
    string id;
    string userId;
    string resourceId;
    int quantity;
    decimal unitPrice;
    decimal totalValue;
    time:Utc timestamp;
    TransactionType 'type;
    string? orderId;
|};

public type SellResourceRequest record {|
    string resourceId;
    int quantity;
|};

public type SellResourceResponse record {|
    decimal earnings;
    decimal newBalance;
    MarketPrice updatedPrice;
    Transaction 'transaction;
|};

public type FulfillOrderRequest record {|
    string orderId;
|};
public type FulfillOrderResponse record {|
    boolean success;
    string message;
    decimal reward;
    decimal newBalance;
    Transaction? 'transaction;
|};

public type SpecialOrderResponse record {|
    SpecialOrder[] orders;
|};

public type MarketPricesResponse record {|
    MarketPrice[] prices;
|};

public type TransactionsResponse record {|
    Transaction[] transactions;
    int total;
|};

public type MarketBasePrice record {|
    string resourceId;
    decimal basePrice;
|};

public type MarketClient record {|
    string id;
    ClientType 'type;
    string name;
|};

public type MarketClientMultiplier record {|
    ClientType 'type;
    decimal multiplier;
|};

public type LaboratoryType "basic"|"advanced"|"institute"|"mining"|"metallurgy"|"mechanical";

public type LaboratorySpecialization "mine"|"furnace"|"assembler"|"general";

public type ResearchCategory "mine"|"furnace"|"assembler"|"general";

public type ResearchEffectType "speed"|"efficiency"|"unlock_recipe"|"cost_reduction"|"bonus_output";

public type Laboratory record {|
    string id;
    string userId;
    LaboratoryType 'type;
    string name;
    decimal cost;
    decimal researchSpeed;  // Multiplicateur de vitesse (1.0 = 100%, 1.5 = 150%)
    int maxSimultaneousResearch;
    LaboratorySpecialization? specialization;
    time:Utc purchaseTime;
|};

public type ResearchEffect record {|
    ResearchEffectType 'type;
    LaboratorySpecialization target;  // "mine", "furnace", "assembler", ou "all" (mais on utilise "general" pour "all")
    decimal value;  // Valeur en % ou absolue
    string description;
|};

public type Research record {|
    string id;
    string name;
    string description;
    ResearchCategory category;
    ResearchRequirement[] requirements;  // Ressources nécessaires
    decimal duration;  // Durée en secondes
    string[] prerequisites;  // IDs des recherches requises avant
    ResearchEffect[] effects;
    string icon;
|};

public type ResearchRequirement record {|
    string resourceId;
    int quantity;
|};

public type ResearchProgress record {|
    string id;
    string userId;
    string researchId;
    string laboratoryId;
    time:Utc startTime;
    time:Utc estimatedEndTime;
    decimal progress;  // 0.0 à 1.0
|};

public type CompletedResearch record {|
    string id;
    string userId;
    string researchId;
    time:Utc completedAt;
|};

public type PurchaseLaboratoryRequest record {|
    LaboratoryType 'type;
|};

public type PurchaseLaboratoryResponse record {|
    Laboratory laboratory;
    decimal newBalance;
|};

public type StartResearchRequest record {|
    string researchId;
    string laboratoryId;
|};

public type StartResearchResponse record {|
    ResearchProgress progress;
    Research research;
|};

public type LaboratoriesResponse record {|
    Laboratory[] laboratories;
|};

public type ResearchesResponse record {|
    Research[] researches;
|};

public type ActiveResearchesResponse record {|
    ResearchProgress[] activeResearches;
|};

public type CompletedResearchesResponse record {|
    CompletedResearch[] completedResearches;
|};

public type ActiveEffectsResponse record {|
    ResearchEffect[] effects;
    map<decimal> bonuses;  // Ex: {"mine_speed": 0.25, "furnace_efficiency": 0.15}
|};

public type LaboratoryTypeInfo record {|
    LaboratoryType 'type;
    string name;
    decimal cost;
    decimal researchSpeed;
    int maxSimultaneousResearch;
    LaboratorySpecialization? specialization;
    string icon;
    string description;
|};