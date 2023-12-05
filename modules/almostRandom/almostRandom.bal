import ballerina/http;
import ballerina/io;
import ballerina/jballerina.java;
import ballerina/time;

const decimal a = 25214903917;
const decimal c = 17;
final decimal & readonly m = <decimal>float:pow(2, 48);
isolated decimal x0 = currentTimeInMilliSeconds();
isolated decimal x0Weather = check getHorowpathanaWindSpeed();

type APIConfig record {|
    string weatherAPIKey;
    string latitude;
    string longitude;
|};

configurable APIConfig apiConfig = ?;

// isolated string weatherAPIKey = apiConfig.weatherAPIKey;
// isolated string latitude = apiConfig.latitude;
// isolated string longitude = apiConfig.longitude;

// configurable string weatherAPIKey = ?;
// configurable string latitude = ?;
// configurable string longitude = ?;

public isolated function createDecimal() returns float {
    return nextFloat();
}

public isolated function createIntInRange(int startRange, int endRange) returns int|Error {
    if startRange >= endRange {
        return error Error("End range value must be greater than the start range value");
    }
    return <int>(lcg() / m * (<decimal>(endRange - 1) - <decimal>startRange) + <decimal>startRange);
}

public isolated function createIntInRangeUsingWeather(int startRange, int endRange, int seedPoint) returns int|Error {
    if startRange >= endRange {
        return error Error("End range value must be greater than the start range value");
    }
    return <int>((lcgWeather() * seedPoint) / m * (<decimal>(endRange - 1) - <decimal>startRange) + <decimal>startRange);
}

isolated function lcg() returns decimal {
    decimal x1;
    lock {
        x1 = (a * x0 + c) % m;
        x0 = x1;
    }
    return x1;
}

isolated function lcgWeather() returns decimal {
    decimal x1;
    lock {
        x1 = (a * x0Weather + c) % m;
        x0Weather = x1;
    }
    return x1;
}

isolated function currentTimeInMilliSeconds() returns decimal {
    time:Utc utc = time:utcNow();
    decimal mills = <decimal>(utc[0] * 1000) + utc[1] * 1000;
    return decimal:round(mills);
}

isolated function nextFloat() returns float {
    handle secureRandomObj = newSecureRandom();
    return nextFloatExtern(secureRandomObj);
}

isolated function newSecureRandom() returns handle = @java:Constructor {
    'class: "java.security.SecureRandom"
} external;

isolated function nextFloatExtern(handle secureRandomObj) returns float = @java:Method {
    name: "nextFloat",
    'class: "java.security.SecureRandom"
} external;

isolated function getHorowpathanaWindSpeed() returns decimal|error {
    io:println(apiConfig);
    http:Client weatherClient = check new ("https://api.openweathermap.org/data/2.5");
    json payload = <json>check weatherClient->get(string `/weather?lat=${apiConfig.latitude}&lon=${apiConfig.longitude}&appid=${apiConfig.weatherAPIKey}`, targetType = json);
    // json payload = <json>check weatherClient->get("https://api.openweathermap.org/data/2.5/weather?lat=8.61&lon=80.82&appid=d9dba2769ccba04636f8e5aa459cbde3", targetType = json);

    io:println(payload.toString());

    return <decimal>check payload.wind.speed;
}
