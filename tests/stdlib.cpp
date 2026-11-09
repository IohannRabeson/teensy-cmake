#include <Arduino.h>

#include <string>
#include <vector>

void setup()
{
    Serial.begin(9600);
}

void loop()
{
    std::vector<std::string> words;
    for (int i = 0; i < 3; ++i)
        words.push_back("word " + std::to_string(i));
    for (std::string const& word : words)
        Serial.println(word.c_str());
    delay(1000);
}
