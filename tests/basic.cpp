#include <Arduino.h>

void setup()
{
    pinMode(LED_BUILTIN, OUTPUT);
    Serial.begin(9600);
}

void loop()
{
    digitalToggle(LED_BUILTIN);
    Serial.println("blink");
    delay(500);
}
