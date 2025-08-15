<?php

namespace App;

class Greeter
{
    public function say(string $name = 'world'): string
    {
        return "Hello, {$name}!";
    }
}
