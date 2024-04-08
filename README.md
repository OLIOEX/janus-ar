# Janus ActiveRecord

<p align="center">
  <img src="assets/janus-logo.png"
     alt="Janus Logo"
     style="float: left; margin: 0 auto; height: 500px;" />
</p>

![Build Status](https://github.com/OLIOEX/janus-ar/actions/workflows/ci.yml/badge.svg)

> In ancient Roman religion and myth, Janus (/ˈdʒeɪnəs/ JAY-nəs; Latin: Ianvs [ˈi̯aːnʊs]) is the god of beginnings, gates, transitions, time, duality, doorways,[2] passages, frames, and endings. [(wikipedia)](https://en.wikipedia.org/wiki/Janus)

Janus ActiveRecord is generic primary/replica proxy for ActiveRecord 7.1+ and MySQL. It handles the switching of connections between primary and replica database servers. It comes with an ActiveRecord database adapter implementation.

Janus is heavily inspired by [Makara](https://github.com/instacart/makara) from TaskRabbit and then Instacart. Unfortunately this project is unmaintained and broke for us with Rails 7.1. This is an attempt to start afresh on the project. It is definitely not as fully featured as Makara at this stage.

## Installation

Use the current version of the gem from [rubygems](https://rubygems.org/gems/janus-ar) in your `Gemfile`.

```ruby
gem 'janus-ar'
```

This project assumes that your read/write endpoints are handled by a separate system (e.g. DNS).

## Usage

After a write request during a thread the adapter will continue using the `primary` server, unless the context is specifically released.

### Configuration

Update your **database.yml** as follows:

```yml
development:
  adapter: janus_mysql2
  janus:
    primary:
      <<: *default
      database: database_name
      host: primary-host.local
    replica:
      <<: *default
      password: ithappenstobedifferent
      host: replica-host.local
```

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

You can set a logger instance to ::Janus::Logging::Logger.logger and Janus.

```ruby
Janus::Logging::Logger.logger = ::Logger.new(STDOUT)
```

### What queries goes where?

In general: Any `SELECT` statements will execute against your replica(s), anything else will go to the primary.

There are some edge cases:
* `SET` operations will be sent to all connections
* Execution of specific methods such as `connect!`, `disconnect!`, `reconnect!`, and `clear_cache!` are invoked on all underlying connections
* Calls inside a transaction will always be sent to the primary (otherwise changes from within the transaction could not be read back on most transaction isolation levels)
* Locking reads (e.g. `SELECT ... FOR UPDATE`) will always be sent to the primary


# Acknowlegements

Amazing project logo by @undevelopedbruce.
