# Janus ActiveRecord

<p align="center">
  <img src="assets/janus-logo.png"
     alt="Janus Logo"
     style="float: left; margin: 0 auto; height: 500px;" />
</p>

> In ancient Roman religion and myth, Janus (/ˈdʒeɪnəs/ JAY-nəs; Latin: Ianvs [ˈi̯aːnʊs]) is the god of beginnings, gates, transitions, time, duality, doorways,[2] passages, frames, and endings. [(wikipedia)](https://en.wikipedia.org/wiki/Janus)

[![CI](https://github.com/OLIOEX/janus-ar/actions/workflows/ci.yml/badge.svg)](https://github.com/OLIOEX/janus-ar/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/janus-ar.svg)](https://badge.fury.io/rb/janus-ar)

Janus ActiveRecord is generic primary/replica proxy for ActiveRecord 7.1+ and MySQL (via `mysql2` and `trilogy`). It handles the switching of connections between primary and replica database servers. It comes with an ActiveRecord database adapter implementation.

Note: Trilogy support is experimental at this stage.

Janus is heavily inspired by [Makara](https://github.com/instacart/makara) from TaskRabbit and then Instacart. Unfortunately this project is unmaintained and broke for us with Rails 7.1. This is an attempt to start afresh on the project. It is definitely not as fully featured as Makara at this stage.

Learn more about its origins: [https://tech.olioex.com/ruby/2024/04/16/introducing-janus.html](https://tech.olioex.com/ruby/2024/04/16/introducing-janus.html).

Notes: GEM is currently tested with MySQL 8, Ruby 3.2, ActiveRecord 7.1+

## Installation

Use the current version of the gem from [rubygems](https://rubygems.org/gems/janus-ar) in your `Gemfile`.

```ruby
gem 'janus-ar'
```

This project assumes that your read/write endpoints are handled by a separate system (e.g. DNS).

## Usage

After a write request during a thread the adapter will continue using the `primary` server, unless the context is specifically released.

## Rails 7.2+

For Rails 7.2 you'll need to manually register the database adaptor in `config/application.rb` after requiring rails but before entering the application configuration, e.g.

```ruby
require 'rails/all'

ActiveRecord::ConnectionAdapters.register("janus_trilogy", "ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter", 'janus-ar/active_record/connection_adapters/janus_trilogy_adapter')
# ...or...
ActiveRecord::ConnectionAdapters.register("janus_mysql2", "ActiveRecord::ConnectionAdapters::JanusMysql2Adapter", 'janus-ar/active_record/connection_adapters/janus_mysql2_adapter')
```

## Rails <= 7.1

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

### Forcing connections

A context is local to the curent thread of execution. This will allow you to stick to the primary safely in a single thread
in systems such as sidekiq, for instance.

#### Releasing stuck connections (clearing context)

If you need to clear the current context, releasing any stuck connections, all you have to do is:

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
* Locking reads (e.g. `SELECT ... FOR UPDATE`) will always be sent to the primary

# Notes

Janus does not support Rails' read/write split or sharding using `with_connection`.

# Acknowlegements

Amazing project logo by @undevelopedbruce.
