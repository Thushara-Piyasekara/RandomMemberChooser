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

    int numOfMembers = potentialMembers.values.length();

    check updateStatusCell(spreadsheetClient, "Getting weather data...");
    int randomNumber = check almostRandom:createIntInRangeUsingWeather(1, numOfMembers - 1, <int>seedPoint.value);
    string randomMember = potentialMembers.values[randomNumber].toString();

    while (numOfMembers > premiumMemberNames.length() && premiumMemberNames.indexOf(randomMember) != ()) {
        randomNumber = check almostRandom:createIntInRangeUsingWeather(1, numOfMembers - 1, <int>seedPoint.value);
        randomMember = potentialMembers.values[randomNumber].toString();
    }

    io:println(randomNumber);

    string winnerName = potentialMembers.values.remove(randomNumber).toString();
    potentialMembers.values.push("");
    completedMembers.values.push(winnerName);

    // Updating the columns
    check updateStatusCell(spreadsheetClient, "Updating Columns...");
    check spreadsheetClient->createOrUpdateColumn(googleSheetID, googleSheetName, "A", potentialMembers.values, "USER_ENTERED");
    check spreadsheetClient->createOrUpdateColumn(googleSheetID, googleSheetName, "B", completedMembers.values, "USER_ENTERED");
    check spreadsheetClient->setCell(googleSheetID, googleSheetName, "E1", winnerName);
    check updateWinnerCell(spreadsheetClient, winnerName);

    check updateStatusCell(spreadsheetClient, "Winner Found");
    return winnerName;
}

function updateStatusCell(sheets:Client spreadsheetClient, string message) returns error? {
    check spreadsheetClient->setCell(googleSheetID, googleSheetName, "E5", message);
}

function updateWinnerCell(sheets:Client spreadsheetClient, string winnerName) returns error? {
    check spreadsheetClient->setCell(googleSheetID, googleSheetName, "E1", winnerName);
}
