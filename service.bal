import RandomMemberChooser.almostRandom;

import ballerina/http;
import ballerina/log;
import ballerinax/googleapis.sheets;

configurable GoogleSheetConfig googleSheetConfigs = ?;
configurable string[] excludedMembers = ?;

type GoogleSheetConfig record {|
    string refreshToken;
    string clientID;
    string clientSecret;
    string googleSheetID;
    string googleSheetName;
|};

final sheets:Client spreadsheetClient = check initializeGoogleSheetClient();

public isolated function initializeGoogleSheetClient() returns sheets:Client|error {

    sheets:ConnectionConfig spreadsheetConfig = {
        auth: {
            clientId: googleSheetConfigs.clientID,
            clientSecret: googleSheetConfigs.clientSecret,
            refreshUrl: sheets:REFRESH_URL,
            refreshToken: googleSheetConfigs.refreshToken
        }
    };

    final sheets:Client gsClient = check new (spreadsheetConfig);

    return gsClient;
}

service / on new http:Listener(9095) {
    resource function get randomMember() returns string|error? {
        string winnerName = check pickRandomMember();
        log:printInfo("winnerName = " + winnerName);
        return winnerName;
    }
}

function pickRandomMember() returns string|error {
    check updateWinnerCell("Pending...");
    check updateStatusCell("Reading Potential Members...");

    sheets:Column potentialMembers = check spreadsheetClient->getColumn(googleSheetConfigs.googleSheetID, googleSheetConfigs.googleSheetName, "A", ());
    sheets:Column completedMembers = check spreadsheetClient->getColumn(googleSheetConfigs.googleSheetID, googleSheetConfigs.googleSheetName, "B", ());
    sheets:Cell seedPoint = check spreadsheetClient->getCell(googleSheetConfigs.googleSheetID, googleSheetConfigs.googleSheetName, "E4", "UNFORMATTED_VALUE");
    log:printInfo("seed point = " + seedPoint.value.toString());

    // First index of the column array is the column name. (i.e., "Potential Members")
    int numOfMembers = potentialMembers.values.length() - 1;
    string winnerName;

    if numOfMembers == 1 {
        winnerName = potentialMembers.values.pop().toString();

        // When all potential members are exhausted, it is necessary to reset the columns
        foreach int i in 1 ... completedMembers.values.length() - 1 {
            potentialMembers.values.push(completedMembers.values[i]);
            completedMembers.values[i] = "";
        }
        completedMembers.values[1] = winnerName;
    } else {
        check updateStatusCell("Getting weather data...");
        int randomNumber = check almostRandom:createIntInRangeUsingWeather(1, numOfMembers + 1, <int>seedPoint.value);
        winnerName = potentialMembers.values[randomNumber].toString();

        while numOfMembers > excludedMembers.length() && excludedMembers.indexOf(winnerName) != () {
            randomNumber = check almostRandom:createIntInRangeUsingWeather(1, numOfMembers + 1, <int>seedPoint.value);
            winnerName = potentialMembers.values[randomNumber].toString();
        }

        _ = potentialMembers.values.remove(randomNumber);
    }

    potentialMembers.values.push("");
    completedMembers.values.push(winnerName);

    // Updating the columns
    check updateStatusCell("Updating Columns...");
    check spreadsheetClient->createOrUpdateColumn(googleSheetConfigs.googleSheetID, googleSheetConfigs.googleSheetName, "A", potentialMembers.values, "USER_ENTERED");
    check updateStatusCell("Winner Found");
    check updateWinnerCell(winnerName);
    check spreadsheetClient->createOrUpdateColumn(googleSheetConfigs.googleSheetID, googleSheetConfigs.googleSheetName, "B", completedMembers.values, "USER_ENTERED");

    return winnerName;
}

function updateStatusCell(string message) returns error? {
    check spreadsheetClient->setCell(googleSheetConfigs.googleSheetID, googleSheetConfigs.googleSheetName, "E5", message);
}

function updateWinnerCell(string winnerName) returns error? {
    check spreadsheetClient->setCell(googleSheetConfigs.googleSheetID, googleSheetConfigs.googleSheetName, "E1", winnerName);
}
