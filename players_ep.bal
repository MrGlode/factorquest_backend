import ballerina/http;
import ballerina/log;

service /players on new http:Listener(server_port +2) {
    resource function get profile(@http:Header string appauth) returns PlayerProfilePublic|http:Unauthorized|http:NotFound|http:InternalServerError {
        JwtPayload|error payload = validateToken(appauth);
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        PlayerProfilePublic|error playerProfile = getPlayerProfilePublic(payload.sub);
        if playerProfile is error {
            log:printError("Erreur lors de la récupération du profil du joueur", 'error = playerProfile);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return playerProfile;
    }

    resource function put stats(@http:Header string appauth, UpdatePlayerStatsRequest updates) returns http:Ok|http:Unauthorized|http:InternalServerError {

        JwtPayload|error payload = validateToken(appauth);
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        error? updateResult = updatePlayerStats(payload.sub, updates);
        if updateResult is error {
            log:printError("Erreur lors de la mise à jour des statistiques du joueur", 'error = updateResult);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return <http:Ok>{
            body: {
                message: "Statistiques mises à jour avec succès."
            }
        };
    }

    resource function post 'increment\-stat(@http:Header string appauth, record {|string statName; int|decimal amount; |} req) returns http:Ok|http:BadRequest|http:Unauthorized|http:InternalServerError {

        JwtPayload|error payload = validateToken(appauth);
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        string[] validStats = [
            "totalMoneyEarned", "totalMoneySpent", "totalPlayTime", "machinesBought",
            "resourcesProduced", "resourcesSold", "researchesCompleted", "specialOrdersCompleted"
        ];

        boolean isValidStat = false;
        foreach string validStat in validStats {
            if validStat == req.statName {
                isValidStat = true;
                break;
            }
        }

        if !isValidStat {
            return <http:BadRequest>{
                body: {
                    message: "Statistique invalide."
                }
            };
        }

        error? incrementResult = incrementStat(payload.sub, req.statName, req.amount);
        if incrementResult is error {
            log:printError("Erreur lors de l'incrémentation de la statistique du joueur", 'error = incrementResult);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return <http:Ok>{
            body: {
                message: "Statistique incrémentée avec succès."
            }
        };
    }

    resource function put level(@http:Header string appauth, record {|int level; int experience;|}req ) returns http:Ok|http:BadRequest|http:Unauthorized|http:InternalServerError {

        JwtPayload|error payload = validateToken(appauth);
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }

        if req.level < 1 || req.experience < 0 {
            return <http:BadRequest>{
                body: {
                    message: "Niveau ou expérience invalide."
                }
            };
        }

        error? updateResult = updateLevelAndExperience(payload.sub, req.level, req.experience);
        if updateResult is error {
            log:printError("Erreur lors de la mise à jour du niveau et de l'expérience du joueur", 'error = updateResult);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return <http:Ok>{
            body: {
                message: "Niveau et expérience mis à jour avec succès."
            }
        };
    }

    resource function get leaderboard(int 'limit = 10) returns PlayerProfilePublic[]|http:BadRequest|http:InternalServerError {
        if 'limit < 1 || 'limit > 100 {
            return <http:BadRequest>{
                body: {
                    message: "Limite invalide. Doit être entre 1 et 100."
                }
            };
        }

        PlayerProfilePublic[]|error leaderboard = getTopPlayers('limit);
        if leaderboard is error {
            log:printError("Erreur lors de la récupération du classement", 'error = leaderboard);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return leaderboard;
    }

    resource function get count() returns json|http:InternalServerError {
        int|error count = countPlayers();
        if count is error {
            log:printError("Erreur lors de la récupération du nombre de joueurs", 'error = count);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }

        return { totalPlayers: count };
    }

    resource function delete profile(@http:Header string appauth) returns http:Ok|http:BadRequest|http:Unauthorized|http:InternalServerError{
        JwtPayload|error payload = validateToken(appauth);
        if payload is error {
            return <http:Unauthorized>{
                body: {
                    message: "Token invalide."
                }
            };
        }
        error? deleteResult = deletePlayerProfile(payload.sub);
        if deleteResult is error {
            log:printError("Erreur lors de la suppression du profil joueur", 'error = deleteResult);
            return <http:InternalServerError>{
                body: {
                    message: "Erreur interne du serveur."
                }
            };
        }
        return <http:Ok>{
            body: {
                message: "Profil joueur supprimé avec succès."
            }
        };
    }
}