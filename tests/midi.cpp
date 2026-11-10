#include <Arduino.h>

void setup()
{
    Serial.begin(9600);
}

void loop()
{
    usbMIDI.sendNoteOn(60, 127, 1);
    delay(500);
    usbMIDI.sendNoteOff(60, 0, 1);
    delay(500);
}
