import ballerina/http;
import ballerina/log;

service /players on new http:Listener(server_port +2) {
    resource function get profile(@http:Header string Authorization) returns PlayerProfilePublic|http:Unauthorized|http:NotFound|http:InternalServerError {
        string token = Authorization.substring(7);

        JwtPayload|error payload = validateToken(token);
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

    resource function put stats(@http:Header string Authorization, UpdatePlayerStatsRequest updates) returns http:Ok|http:Unauthorized|http:InternalServerError {
        string token = Authorization.substring(7);

        JwtPayload|error payload = validateToken(token);
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
}