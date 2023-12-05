import RandomMemberChooser.almostRandom;

import ballerina/io;
import ballerinax/googleapis.sheets;

type GoogleSheetConfig record {|
    string refreshToken;
    string clientID;
    string clientSecret;
|};

configurable GoogleSheetConfig googleSheetConfigs = ?;
configurable string googleSheetID = ?;
configurable string googleSheetName = ?;
configurable string[] premiumMemberNames = ?;

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

public function main() returns error? {
    final sheets:Client spreadsheetClient = check initializeGoogleSheetClient();
    // sheets:Spreadsheet|error sheet = spreadsheetClient->openSpreadsheetById(googleSheetID);

    string winnerName = check pickRandomMember(spreadsheetClient);
    io:println(winnerName);
}

function pickRandomMember(sheets:Client spreadsheetClient) returns string|error {
    check updateWinnerCell(spreadsheetClient, "Pending...");
    check updateStatusCell(spreadsheetClient, "Reading Potential Members...");

    sheets:Column potentialMembers = check spreadsheetClient->getColumn(googleSheetID, googleSheetName, "A", ());
    sheets:Column completedMembers = check spreadsheetClient->getColumn(googleSheetID, googleSheetName, "B", ());
    sheets:Cell seedPoint = check spreadsheetClient->getCell(googleSheetID, googleSheetName, "E4", "UNFORMATTED_VALUE");

    int numOfMembers = potentialMembers.values.length() - 1;
    io:println("num of members : " + numOfMembers.toString());

    string winnerName;
    if (numOfMembers == 1) {
        winnerName = potentialMembers.values.pop().toString();

        // When all potential members are exhausted, it is necessary to reset the columns
        foreach int i in 1 ... completedMembers.values.length() - 1 {
            potentialMembers.values.push(completedMembers.values[i]);
            completedMembers.values[i] = "";
        }
        completedMembers.values[1] = winnerName;
    }
    else {
        check updateStatusCell(spreadsheetClient, "Getting weather data...");
        int randomNumber = check almostRandom:createIntInRangeUsingWeather(1, numOfMembers - 1, <int>seedPoint.value);
        winnerName = potentialMembers.values[randomNumber].toString();

        while (numOfMembers > premiumMemberNames.length() && premiumMemberNames.indexOf(winnerName) != ()) {
            randomNumber = check almostRandom:createIntInRangeUsingWeather(1, numOfMembers - 1, <int>seedPoint.value);
            winnerName = potentialMembers.values[randomNumber].toString();
        }

        io:println(randomNumber);

        _ = potentialMembers.values.remove(randomNumber);
    }
    potentialMembers.values.push("");
    completedMembers.values.push(winnerName);

    // Updating the columns
    check updateStatusCell(spreadsheetClient, "Updating Columns...");
    check spreadsheetClient->createOrUpdateColumn(googleSheetID, googleSheetName, "A", potentialMembers.values, "USER_ENTERED");
    check spreadsheetClient->createOrUpdateColumn(googleSheetID, googleSheetName, "B", completedMembers.values, "USER_ENTERED");
    check spreadsheetClient->setCell(googleSheetID, googleSheetName, "E1", winnerName);
    check updateStatusCell(spreadsheetClient, "Winner Found");

    check updateWinnerCell(spreadsheetClient, winnerName);
    return winnerName;
}

function updateStatusCell(sheets:Client spreadsheetClient, string message) returns error? {
    check spreadsheetClient->setCell(googleSheetID, googleSheetName, "E5", message);
}

function updateWinnerCell(sheets:Client spreadsheetClient, string winnerName) returns error? {
    check spreadsheetClient->setCell(googleSheetID, googleSheetName, "E1", winnerName);
}
