<?php

namespace App\Tests;

use App\Greeter;
use PHPUnit\Framework\TestCase;

class GreeterTest extends TestCase
{
    public function test_it_greets_a_name(): void
    {
        $greeter = new Greeter();
        $this->assertSame('Hello, Alice!', $greeter->say('Alice'));
    }

    public function test_it_defaults_to_world(): void
    {
        $greeter = new Greeter();
        $this->assertSame('Hello, world!', $greeter->say());
    }
}
