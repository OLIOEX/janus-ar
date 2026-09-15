# Janus ActiveRecord

<p align="center">
  <img src="assets/janus-logo.png"
     alt="Janus Logo"
     style="float: left; margin: 0 auto; height: 500px;" />
</p>

> In ancient Roman religion and myth, Janus (/ˈdʒeɪnəs/ JAY-nəs; Latin: Ianvs [ˈi̯aːnʊs]) is the god of beginnings, gates, transitions, time, duality, doorways,[2] passages, frames, and endings. [(wikipedia)](https://en.wikipedia.org/wiki/Janus)

[![CI](https://github.com/OLIOEX/janus-ar/actions/workflows/ci.yml/badge.svg)](https://github.com/OLIOEX/janus-ar/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/janus-ar.svg)](https://badge.fury.io/rb/janus-ar)

Janus ActiveRecord is a generic primary/replica proxy for ActiveRecord 8, supporting MySQL (via `mysql2` and `trilogy`) and PostgreSQL (via `pg`). It handles the switching of connections between primary and replica database servers. It comes with an ActiveRecord database adapter implementation.

Janus is heavily inspired by [Makara](https://github.com/instacart/makara) from TaskRabbit and then Instacart. Unfortunately this project is unmaintained and broke for us with Rails 7.1. This is an attempt to start afresh on the project. It is definitely not as fully featured as Makara at this stage.

Learn more about its origins: [https://tech.olioex.com/ruby/2024/04/16/introducing-janus.html](https://tech.olioex.com/ruby/2024/04/16/introducing-janus.html).

Notes: the gem requires ActiveRecord `>= 8.0, < 9.0` and Ruby `>= 3.2`, and is tested against MySQL 8 and PostgreSQL 16 and 17.

## Installation

Use the current version of the gem from [rubygems](https://rubygems.org/gems/janus-ar) in your `Gemfile`.

```ruby
gem 'janus-ar'
```

This project assumes that your read/write endpoints are handled by a separate system (e.g. DNS).

## Usage

After a write request during a thread the adapter will continue using the `primary` server, unless the context is specifically released.

### Setup 

#### Rails 7.2+

For Rails 7.2 you'll need to manually register the database adaptor in `config/application.rb` after requiring rails but before entering the application configuration, e.g.

```ruby
require 'rails/all'

ActiveRecord::ConnectionAdapters.register("janus_trilogy", "ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter", 'janus-ar/active_record/connection_adapters/janus_trilogy_adapter')
# ...or...
ActiveRecord::ConnectionAdapters.register("janus_mysql2", "ActiveRecord::ConnectionAdapters::JanusMysql2Adapter", 'janus-ar/active_record/connection_adapters/janus_mysql2_adapter')
# ...or...
ActiveRecord::ConnectionAdapters.register("janus_postgresql", "ActiveRecord::ConnectionAdapters::JanusPostgreSQLAdapter", 'janus-ar/active_record/connection_adapters/janus_postgresql_adapter')
```

#### Rails <= 7.1

ActiveRecord 7.1 was tested up to releases v0.15.*. After this release we only tested  Rails 7.2+. This does not mean it is not compatible, just not tested.

### Configuration

Update your **database.yml** as follows:

```yml
development:
  adapter: janus_mysql2
  database: database_name
  janus:
    primary:
      <<: *default
      host: primary-host.local
    replica:
      <<: *default
      password: ithappenstobedifferent
      host: replica-host.local
```
Note: For `trilogy` please use adapter "janus_trilogy". You'll probably need to add the following to your configuration to have it connect:

```yml
  ssl: true
  ssl_mode: 'REQUIRED'
  tls_min_version: 3
```

`tls_min_version` here refers to TLS1.2.

Otherwise you will get an error like the following (see https://github.com/trilogy-libraries/trilogy/issues/26):
> trilogy_auth_recv: caching_sha2_password requires either TCP with TLS or a unix socket: TRILOGY_UNSUPPORTED"

#### PostgreSQL

Use adapter `janus_postgresql`, and add the `pg` gem to your `Gemfile`:

```yml
development:
  adapter: janus_postgresql
  database: database_name
  janus:
    primary:
      <<: *default
      host: primary-host.local
      username: app
      password: primary_password
    replica:
      <<: *default
      host: replica-host.local
      username: app_readonly
      password: replica_password
```

Anything the adapter reads out of its own configuration — `pool`, `prepared_statements`,
`insert_returning`, `variables`, `schema_search_path`, SSL settings and so on — must go
inside the `primary:` and `replica:` blocks rather than alongside `adapter:`, because each
connection is built from its own block.

Two things worth knowing about the PostgreSQL adapter specifically:

* Unlike MySQL, PostgreSQL never inlines bind values into the statement: reads
  reach the replica as `$1` placeholders plus a separate parameter list, and
  prepared statements are cached per connection. The adapter forwards binds and
  the prepare flag to the replica, so each connection maintains its own
  statement cache.
* Type OIDs are resolved against whichever connection served the lookup. This is
  correct for a physical (streaming) replica, where OIDs are identical to the
  primary's by construction. If you point Janus at a logical replica whose custom
  types, enums or extensions were created independently, the OIDs can diverge and
  results may be cast with the wrong type.

### Forcing connections

A context is local to the current unit of work (thread or fiber, following ActiveRecord's configured isolation level). This allows you to stick to the primary safely within a single request or job, in systems such as Sidekiq for instance.

#### Releasing stuck connections (clearing context)

In a Rails application the context is released automatically at the start of every unit of work wrapped by the Rails executor — web requests, ActiveJob and Sidekiq-on-Rails jobs — so stickiness from a write never leaks into the next request on a reused thread. You do not need to do anything for this.

Outside of Rails (or to clear the context manually), call:

```ruby
Janus::Context.release_all
```

#### Forcing connection to primary server

```ruby
Janus::Context.stick_to_primary
```

### Logging

You can set a logger instance to `::Janus::Logging::Logger.logger`:

```ruby
Janus::Logging::Logger.logger = ::Logger.new(STDOUT)
```

If using `ActiveRecord` logging, Janus will append the name of the connection used to any logs e.g. `[primary]` or `[replica]`.

### What queries goes where?

In general: Any `SELECT` statements will execute against your replica(s), anything else will go to the primary.

There are some edge cases:
* `SET` operations will be sent to all connections
* Execution of specific methods such as `connect!`, `disconnect!`, `reconnect!`, and `clear_cache!` are invoked on all underlying connections
* Calls inside a transaction will always be sent to the primary (otherwise changes from within the transaction could not be read back on most transaction isolation levels)
* Locking reads (e.g. `SELECT ... FOR UPDATE`, `FOR UPDATE SKIP LOCKED`, `FOR SHARE`, `FOR NO KEY UPDATE`, `FOR KEY SHARE`, `LOCK IN SHARE MODE`) will always be sent to the primary
* So will reads that call a locking or sequence function — `GET_LOCK(...)`, `IS_FREE_LOCK(...)`, `nextval(...)`, `setval(...)` and PostgreSQL's advisory lock family (`pg_advisory_lock`, `pg_try_advisory_xact_lock_shared`, `pg_advisory_unlock_all`, and so on)
* PostgreSQL cursor statements (`DECLARE`, `FETCH`, `MOVE`, `CLOSE`) go to the primary, so a cursor is always fetched on the connection that declared it

# Notes

Janus does not support Rails' read/write split or sharding using `with_connection`.

# Acknowlegements

Amazing project logo by @undevelopedbruce.

## Releasing

Releases are cut from the [GitHub Releases UI](https://github.com/OLIOEX/janus-ar/releases/new).
Publishing to RubyGems is automatic — there is nothing to bump by hand, and no
API key to rotate (authentication uses RubyGems
[trusted publishing](https://guides.rubygems.org/trusted-publishing/) over OIDC).

To release:

1. Create a new release against the head of `main`, with a tag named
   `vMAJOR.MINOR.PATCH` — e.g. `v8.1.0`. Pre-release suffixes use a dot, as
   RubyGems requires: `v8.1.0.rc1`, not `v8.1.0-rc1`.
2. Publish it.

[`.github/workflows/publish.yml`](.github/workflows/publish.yml) then takes the
version from the tag, writes it into `lib/janus-ar/version.rb`, refreshes
`Gemfile.lock`, commits that bump to `main` as `Release vX.Y.Z`, moves the tag
onto that commit, and pushes the gem.

Because the bump is committed to `main`, releases must be created from its head
— the workflow refuses to publish if the tag sits anywhere else. You never need
to edit `version.rb` yourself; the tag is the source of truth.
