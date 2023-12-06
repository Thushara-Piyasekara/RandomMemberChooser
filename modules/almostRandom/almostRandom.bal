import ballerina/http;
import ballerina/log;
import ballerina/time;

configurable APIConfig apiConfig = ?;
isolated decimal x0Weather = check getHorowpathanaWindSpeed() * currentTimeInMilliSeconds();
const decimal a = 25214903917;
const decimal c = 17;
final decimal & readonly m = <decimal>float:pow(2, 48);

final http:Client weatherClient = check new (apiConfig.clientAPI);

type APIConfig record {|
    string clientAPI;
    string weatherAPIKey;
    string latitude;
    string longitude;
|};

public isolated function createIntInRangeUsingWeather(int startRange, int endRange, int seedPoint) returns int|Error {
    if startRange >= endRange {
        return error Error("End range value must be greater than the start range value");
    }

    int randomInt = <int>(lcgWeather(seedPoint) / m * (<decimal>(endRange - 1) - <decimal>startRange) + <decimal>startRange);
    log:printInfo("randomInt :" + randomInt.toString());

    return randomInt;
}

isolated function lcgWeather(int seedPoint) returns decimal {
    decimal x1;
    lock {
        x1 = (a * (x0Weather / seedPoint) + c) % m;
        x0Weather = x1;
    }
    log:printInfo("lcg :" + x1.toString());

    return x1;
}

isolated function currentTimeInMilliSeconds() returns decimal {
    time:Utc utc = time:utcNow();
    decimal mills = <decimal>(utc[0] * 1000) + utc[1] * 1000;
    return decimal:round(mills);
}

isolated function getHorowpathanaWindSpeed() returns decimal|error {
    json payload = check weatherClient->/weather.get(
        lat = apiConfig.latitude,
        lon = apiConfig.longitude,
        appid = apiConfig.weatherAPIKey
    );

    decimal windSpeed = <decimal>check payload.wind.speed;

    log:printInfo("wind speed :" + windSpeed.toString());
    return windSpeed;
}
