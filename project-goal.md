Goal

Build a modular, extensible SQL Builder in PHP using the Builder design pattern with an Orchestrator that composes per-clause builders (select, where, join, etc.). Support read & write queries (select/insert/update/delete/upsert/truncate), raw SQL, parameter binding, aggregates, toSql(), getBindings(), column discovery, and a Laravel-like Collection for results (first, pluck, where, sum, count, toArray). Include tests for each module. Use PDO with a config file. Default tests use SQLite in-memory; optionally allow MySQL/Postgres via env.

Feel free to search the existing file structure to work with it appropriately

Repo structure
sql-builder/
├─ src/
│  ├─ Config/DatabaseConfig.php
│  ├─ Connection/ConnectionInterface.php
│  ├─ Connection/PdoConnection.php
│  ├─ Grammar/GrammarInterface.php
│  ├─ Grammar/MySqlGrammar.php
│  ├─ Grammar/SQLiteGrammar.php
│  ├─ Grammar/PostgresGrammar.php
│  ├─ Query/Contracts/Compilable.php
│  ├─ Query/Contracts/Executable.php
│  ├─ Query/BuilderOrchestrator.php         // single entry point; fluent facade
│  ├─ Query/Clauses/SelectBuilder.php
│  ├─ Query/Clauses/FromBuilder.php
│  ├─ Query/Clauses/JoinBuilder.php
│  ├─ Query/Clauses/WhereBuilder.php
│  ├─ Query/Clauses/GroupByBuilder.php
│  ├─ Query/Clauses/HavingBuilder.php
│  ├─ Query/Clauses/OrderLimitBuilder.php
│  ├─ Query/Clauses/AggregateBuilder.php
│  ├─ Query/Mutation/InsertBuilder.php
│  ├─ Query/Mutation/UpdateBuilder.php
│  ├─ Query/Mutation/DeleteBuilder.php
│  ├─ Query/Mutation/TruncateBuilder.php
│  ├─ Result/Collection.php
│  ├─ Result/Row.php
│  ├─ Support/Expression.php                 // for raw(), selectRaw(), whereRaw() tokens
│  └─ Support/Bindings.php
├─ config/
│  └─ database.php.example
├─ tests/
│  ├─ bootstrap.php
│  ├─ Unit/… (per class)
│  └─ Integration/… (end-to-end)
├─ composer.json
├─ phpunit.xml
└─ README.md

Tech assumptions
PHP 8.3; Composer; PHPUnit ^11.0.
PDO for DB; run unit tests on SQLite in-memory by default.
PSR-4 autoloading.


Acceptance criteria (high level)
Fluent API matching the examples in the brief.
toSql() returns SQL with placeholders; getBindings() returns bindings.
get() returns Collection; first() returns a single associative array or Row.
All listed query APIs exist and are tested (see “Feature parity checklist” below).
Drivers: SQLite first; implement MySQL and Postgres grammar shims for upsert/truncate/columns.

Step 1 
Add config/database.php.example:

return [
  'default' => getenv('DB_CONNECTION') ?: 'sqlite',
  'connections' => [
    'sqlite' => ['driver'=>'sqlite','database'=>':memory:','prefix'=>''],
    'mysql'  => ['driver'=>'mysql','host'=>'127.0.0.1','port'=>3306,'database'=>'app','username'=>'root','password'=>'','charset'=>'utf8mb4','collation'=>'utf8mb4_unicode_ci'],
    'pgsql'  => ['driver'=>'pgsql','host'=>'127.0.0.1','port'=>5432,'database'=>'app','username'=>'postgres','password'=>'','charset'=>'utf8'],
  ],
];

Add tests/bootstrap.php to load Composer and create a test connection (SQLite in-memory), create a few tables (posts, users, orders, comments) and seed minimal data.

Tests: Add a smoke test asserting the SQLite connection works.

If it fails keep moving forwards




<!-- ! ****************************** start here ****************************** -->




Step 2 - Config & Connection

Implement DatabaseConfig to load array config, with fromPath() and fromArray().

Define ConnectionInterface with: getPdo(), select($sql,$bindings), statement($sql,$bindings), transaction(Closure $cb).

Implement PdoConnection with prepared statements and safe binding, throwing descriptive exceptions.

Unit tests:

PdoConnectionTest: select, insert/update/delete via statement, transaction commit/rollback.

Step 3 - Grammar layer

GrammarInterface exposes compilers for:

compileSelect($state), compileInsert($state), compileUpdate($state), compileDelete($state), compileTruncate($state), compileUpsert($state), compileColumns($table).

Provide base helpers for quoting identifiers and placeholders.

Implement SQLiteGrammar, MySqlGrammar, PostgresGrammar:

Upsert forms:

SQLite/Postgres: INSERT ... ON CONFLICT (cols) DO UPDATE SET ...

MySQL: INSERT ... ON DUPLICATE KEY UPDATE ...

Truncate: use driver-appropriate SQL (MySQL TRUNCATE TABLE, Postgres TRUNCATE ... RESTART IDENTITY, SQLite DELETE FROM + VACUUM optionally).

compileColumns():

SQLite: PRAGMA table_info(table)

MySQL: SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?

Postgres: SELECT column_name FROM information_schema.columns WHERE table_name = ?

Unit tests:

Grammar tests for each driver (use strings, no DB calls).

Step 4 — Support types

Expression wrapper to mark raw SQL segments (raw('SUM(x)')) without quoting.

Bindings helper to collect and merge parameter arrays consistently.

Unit tests:

Ensure raw expressions bypass quoting and do not become bindings.

Step 5 — Clause builders (pure state & compilation)

Represent query state as a single immutable-ish array/object ($state) with keys: table, columns, distinct, joins, wheres, groups, havings, orders, limit, offset, aggregate, unions, etc. Each clause builder:

Accepts current $state, returns updated $state.

Does not talk to PDO; only mutates state (pure data).

Implement:

FromBuilder::table($name)

SelectBuilder::select($columns = ['*']), selectRaw(Expression $e)

JoinBuilder::join/leftJoin/rightJoin($table,$left,$op,$right)

WhereBuilder methods:

where($col,$opOrVal=null,$val=null) with overloads:

where('id',1)

where('status','!=',1)

where([ 'status'=>'published', 'author_id'=>42 ])

where([ ['published','!=',1], ['author_id','=',42] ])

whereRaw($sql, $bindings = [])

whereIn($col, array $vals), whereNotIn(...)

whereNull($col), whereNotNull($col)

orWhere(...)

Grouped parentheses: where(Closure $nested) returning a grouped AND (...) with nested state.

whereBetween($col, [$a,$b]), whereNotBetween(...)

Date helpers: whereDate($col,$date), whereYear($col,$year)

GroupByBuilder::groupBy(array|string $cols)

HavingBuilder::having($col,$op,$val), havingRaw($sql,$bindings=[])

OrderLimitBuilder::orderBy($col,$dir='asc'), distinct(), limit($n)

AggregateBuilder::count(), sum($col), etc. (sets $state['aggregate'])

Unit tests:

For each builder, assert $state shape and that toSql() later compiles correctly.

Step 6 — Mutations

Implement separate builders that take a payload and produce $sql,$bindings:

InsertBuilder::insert($table, array $data)

InsertBuilder::insertGetId($table, array $data)

InsertBuilder::insertGetRecord($table, array $data)

InsertBuilder::upsert($table, array $rows, array $conflictCols, array $updateCols)

UpdateBuilder::update($table, array $data, $whereState)

DeleteBuilder::delete($table, $whereState)

TruncateBuilder::truncate($table)

Unit & Integration tests:

Run against SQLite memory tables; assert rows changed, insertGetId returns id, insertGetRecord returns the row.

Step 7 — Orchestrator (public API)

BuilderOrchestrator is the single fluent entry used by consumers:

Holds: ConnectionInterface $conn, GrammarInterface $grammar, array $state (starts empty).

Methods route to clause builders and return $this.

Execution methods:

get(): Collection → compiles select, executes via conn->select, wraps Collection.

first() → get()->first().

find($id, $key='id') → where($key,$id)->first().

toSql(): string, getBindings(): array

raw($sql, $bindings = []) → executes as select or statement depending on SQL verb (for simplicity: provide rawSelect and rawStatement initially).

getColumns(): array → grammar-specific query.

Mutations: insert, insertGetId, insertGetRecord, update, updateGetRecord, delete, truncate, upsert.

Static factory Builder::make($conn,$grammar) to ease creation.

Integration tests:

Implement the entire example list from the user (below) and assert SQL + results equivalence.

Step 8 — Collection

Implement Result\Collection with methods:

count(), toArray(), first()

pluck($key) : array

where($keyOrArray, $opOrVal = null, $val = null) : Collection (in-memory filtering)

sum($key), map, filter (basic only)

ArrayAccess & IteratorAggregate for convenience.

Unit tests:

Cover each method, including chained get()->where([...])->sum('total').

Step 9 — Safety & DX

Always use positional bindings ? with a clean Bindings collector.

Quote identifiers with grammar driver (e.g., backticks for MySQL, double quotes for PG, raw for SQLite).

Provide helpful exceptions: missing table, empty update() payload, invalid join operator, etc.

README.md with quickstart and examples (mirror tests).

Feature parity checklist (mirror these as tests)

raw

rawSelect('SELECT * FROM posts')

rawSelect('SELECT * FROM comments WHERE published = ? AND author_id = ?', [1, 42])

table

table('posts') (required before select/mutate)

select

select(['title','body','created_at','updated_at']) (default *)

selectRaw

selectRaw('*, COUNT(*) as total')->groupBy('id')

join/leftJoin/rightJoin

With select of joined columns

find

find(1) default pk id

where variants

All listed (scalar, array eq, array tuples, raw, in/notIn, null/notNull, closure group, orWhere, between/notBetween, whereDate, whereYear)

groupBy/having/havingRaw

orderBy/distinct/limit

delete/update/updateGetRecord

insert/insertGetId/insertGetRecord

upsert(conflictCols, updateCols)

get/getColumns/toSql/truncate

aggregates: count(), sum('total')

collection-like

first, pluck, get()->count(), get()->toArray(), get()->where(...), get()->sum('total')

Developer ergonomics

Add Acme\SqlBuilder\Support\helpers.php with raw($sql) returning Expression.

Add QueryFactory to choose grammar by DSN/driver.

Provide Query facade class with static make() for one-liners:

$query = Query::make(config_path: 'config/database.php');

Example usage (must pass integration tests)
$query = Query::make()->table('posts');

// examples mirrored from the spec…
$query->rawSelect('SELECT * FROM posts');
$query->rawSelect('SELECT * FROM comments WHERE published = ? AND author_id = ?', [1, 42]);

$query->table('posts');
$query->select(['title', 'body', 'created_at', 'updated_at']);
$query->selectRaw('*, COUNT(*) as total')->groupBy('id');

$query->table('posts')
    ->join('users', 'posts.user_id', '=', 'users.id')
    ->select(['posts.*', 'users.name']);

$query->table('posts')
    ->leftJoin('users', 'posts.user_id', '=', 'users.id')
    ->select(['posts.*', 'users.name']);

$query->table('posts')
    ->rightJoin('users', 'posts.user_id', '=', 'users.id')
    ->select(['posts.*', 'users.name']);

$query->find(1);

$query->where('id', 1);
$query->where('published', '!=', 1);
$query->where(['status' => 'published', 'author_id' => 42]);
$query->where([ ['published','!=',1], ['author_id','=',42] ]);
$query->whereRaw('created_at >= ?', ['2021-01-01']);
$query->whereIn('id',[1,2,3]);
$query->whereIn('status',['published','draft']);
$query->whereNotIn('id',[4,5,6]);
$query->whereNull('deleted_at');
$query->whereNotNull('published_at');

$query->where(function($q) {
    $q->where('status','draft')->orWhere('status','archived');
});

$query->where('status','draft')->orWhere('status','archived');

$query->whereBetween('created_at',['2021-01-01','2021-12-31']);
$query->whereNotBetween('views',[100,200]);

$query->whereDate('created_at','2025-08-20');
$query->whereYear('created_at',2025);

$query->groupBy('author_id');

$query->selectRaw('COUNT(*) as total')->having('total','>',1);
$query->selectRaw('SUM(total) as total')->havingRaw('SUM(total) > ?', [100]);

$query->orderBy('created_at','desc');
$query->distinct()->select('author_id');
$query->limit(10);

$query->where(['status'=>'published','author_id'=>42])->delete();

$query->where('id',1)->update(['title'=>'Updated Title','body'=>'Updated Body']);
$record = $query->table('posts')->where('id',1)->updateGetRecord(['title'=>'Updated Title','body'=>'Updated Body']);

$query->table('posts')->insert(['title'=>'New Post','body'=>'Content','published'=>1]);
$id = $query->table('posts')->insertGetId(['title'=>'Another Post','body'=>'With ID returned']);
$record = $query->table('posts')->insertGetRecord(['title'=>'Another Post','body'=>'With ID returned']);

$query->table('posts')->upsert(
  [['id'=>1,'title'=>'Updated'],['id'=>2,'title'=>'Inserted']],
  ['id'],
  ['title']
);

$query->table('posts')->whereNull('deleted_at')->orderBy('created_at','desc')->limit(10)->get();
$query->table('posts')->getColumns();
$sql = $query->where('id',1)->toSql();
$query->truncate();

$query->table('posts')->count();
$query->table('orders')->sum('total');

// Collection samples
$query->table('posts')->first();
$query->table('posts')->pluck('title');
$query->table('posts')->get()->count();
$query->table('posts')->get()->toArray();
$query->table('posts')->get()->where('published',1);
$query->table('posts')->get()->where(['published'=>1,'author_id'=>42]);
$query->table('posts')->get()->sum('total');

Testing plan (what to generate)

Unit: each builder, grammar, collection, connection.

Integration: end-to-end CRUD & aggregates on SQLite in-memory with schema:

users(id integer pk, name text)

posts(id integer pk, user_id int, title text, body text, published int, deleted_at nullable datetime, created_at datetime, updated_at datetime)

comments(id, post_id, author_id, published int, created_at)

orders(id, total numeric)

Assertions for both toSql() shape and execution results where applicable.

Nice-to-haves (after green tests)

Transactions on mutation chains: $query->table('posts')->transaction(fn($q)=>{ ... });

Pagination helper: paginate($perPage,$page=1) returning metadata + collection.

Query events/logging hook.

Caching compiled SQL for identical states (optional).

Typed Rows via simple Row value object (optional).

Clarifying questions (please answer before running the plan)

Target DBs: Do you need SQLite only for now, or full support for MySQL and Postgres (grammar differences for upsert/truncate/quoting)?

Return types: Should first() return an associative array, a Row object, or null on no results?

Right join on SQLite (emulated via LEFT JOIN rewrite) — keep it emulated or restrict per-driver?

Identifier quoting: Prefer default driver quoting (`, ", none) or a unified style?

raw() behavior: Do you want a single raw() that auto-detects the verb, or two explicit methods rawSelect() and rawStatement()?

Error style: Throw custom exceptions (e.g., QueryException, GrammarException) or use generic RuntimeException?

Collection filtering: The in-memory where() supports =, !=, >, <, etc.—good? Should it also support closures?

Upsert behavior: On conflict, return inserted/updated record(s), id(s), or just row count?

Column discovery: Is getColumns() enough, or do you also want types/nullability?

Config loading: Will you pass an array at runtime, or read from a file path + env vars?

Answer these and I’ll tweak the plan (or Copilot can) to fit perfectly.


























































<?php

// I am planning on building a SQL builder using the builder design pattern. It will mimic a lot of the functionality of Laravel's eloquent models. The code must be modular and extensible. I need test with each section. I desire an overarching orchestrating class that includes all the different classes for builder functionality. 

// I will also need a configuration file so we can connect to the database.

// I need the ability to query the database.

// I need to build something that's similar to a Laravel collection that returns from the database.

// I will be using GitHub Copilot agent mode to build this. Will you create a set of instructions that I can give to GitHub Copilot? 

// Please ask questions for clarification to make the instructions more robust!

// let me know if I should add anything else?

// Examples of functionality I would like.

// raw
$query->raw('SELECT * FROM posts');
$query->raw('
    SELECT *
    FROM comments
    WHERE published = ?
        AND author_id = ?
', [1, 42]);

// table
$query->table('posts'); // required

// select
$query->select(['title', 'body', 'created_at', 'updated_at', '...']); // '*' by default

// selectRaw
$query->selectRaw('*, COUNT(*) as total')->groupBy('id');

// join
$query->table('posts')
    ->join('users', 'posts.user_id', '=', 'users.id')
    ->select(['posts.*', 'users.name']);

// leftJoin
$query->table('posts')
    ->leftJoin('users', 'posts.user_id', '=', 'users.id')
    ->select(['posts.*', 'users.name']);

// rightJoin
$query->table('posts')
    ->rightJoin('users', 'posts.user_id', '=', 'users.id')
    ->select(['posts.*', 'users.name']);

// find
$query->find(1); // anticipates id is the primary key

// where
$query->where('id', 1);
$query->where('published', '!=', 1);
$query->where([
    'status' => 'published',
    'author_id' => 42
]);
$query->where([
    ['published', '!=', 1],
    ['author_id', '=', 42]
]);

// whereRaw
$query->whereRaw('created_at >= ?', ['2021-01-01']);

// whereIn
$query->whereIn('id', [1, 2, 3]);
$query->whereIn('status', ['published', 'draft']);

// whereNotIn
$query->whereNotIn('id', [4, 5, 6]);

// whereNull
$query->whereNull('deleted_at');

// whereNotNull
$query->whereNotNull('published_at');

// ********* Parentheses separated where statements.
$query->where(function($q) {
    $q->where('status', 'draft')
        ->orWhere('status', 'archived');
});

// orWhere
$query->where('status', 'draft')->orWhere('status', 'archived');

// between / notBetween
$query->whereBetween('created_at', ['2021-01-01', '2021-12-31']);
$query->whereNotBetween('views', [100, 200]);

// date helpers
$query->whereDate('created_at', '2025-08-20');
$query->whereYear('created_at', 2025);

// groupBy
$query->groupBy('author_id');

// having
$query->selectRaw('COUNT(*) as total')->having('total', '>', 1);

// havingRaw
$query->selectRaw('SUM(total) as total')->havingRaw('SUM(total) > ?', [100]);

// orderBy
$query->orderBy('created_at', 'desc'); // repeat if others needed, ascending by default

// distinct
$query->distinct()->select('author_id');

// limit
$query->limit(10);

// delete
$query->where([
    'status' => 'published',
    'author_id' => 42
])->delete();

// update
$query->where('id', 1)->update([
    'title' => 'Updated Title',
    'body' => 'Updated Body',
]);

// update get record
$record = $query->table('posts')->where('id', 1)->updateGetRecord([
    'title' => 'Updated Title',
    'body' => 'Updated Body',
]);

// insert
$query->table('posts')->insert([
    'title' => 'New Post',
    'body' => 'Content',
    'published' => 1,
]);

// insertGetId
$id = $query->table('posts')->insertGetId([
    'title' => 'Another Post',
    'body' => 'With ID returned',
]);

// insert get record
$record = $query->table('posts')->insertGetRecord([
    'title' => 'Another Post',
    'body' => 'With ID returned',
]);

// upsert (insert or update on conflict)
$query->table('posts')->upsert([
    ['id' => 1, 'title' => 'Updated'],
    ['id' => 2, 'title' => 'Inserted'],
], ['id'], ['title']);

// get
$query->table('posts')
    ->whereNull('deleted_at')
    ->orderBy('created_at', 'desc')
    ->limit(10)
    ->get();

// get columns
$query->table('posts')->getColumns(); // gets all columns, ex ['id', 'title', 'body', 'created_at', 'updated_at']

// toSql
$sql = $query->where('id', 1)->toSql();

// truncate
$query->truncate();

// aggregate
$query->table('posts')->count();
$query->table('orders')->sum('total');

// collection like functionality
// first / pluck
$query->table('posts')->first();
$query->table('posts')->pluck('title'); // single column
$query->table('posts')->get()->count();
$query->table('posts')->get()->toArray();
$query->table('posts')->get()->where('published', 1);
$query->table('posts')->get()->where([
    'published' => 1,
    'author_id' => 42
]);
$query->table('posts')->get()->sum('total'); // sum of total column




















// ********* subquery

// whereExists, // TODO: look into this, do we need it is it faster?
$query->table('posts')->whereExists(function($q) {
    $q->table('comments')->whereRaw('comments.post_id = posts.id');
});