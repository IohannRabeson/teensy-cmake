#include <Arduino.h>

#include <array>
#include <concepts>
#include <span>

template <std::integral T>
constexpr T sum(std::span<T const> values)
{
    T total{};
    for (T value : values)
        total += value;
    return total;
}

static_assert(__cplusplus >= 202002L);

void setup()
{
    Serial.begin(9600);
}

void loop()
{
    static constexpr std::array<int, 4> values{1, 2, 3, 4};
    Serial.println(sum(std::span<int const>{values}));
    delay(1000);
}
