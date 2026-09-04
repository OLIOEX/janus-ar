# frozen_string_literal: true
module Janus
  class QueryDirector
    ALL = :all
    REPLICA = :replica
    PRIMARY = :primary

    # Reading any of these takes or inspects a lock, so it has to happen on the
    # primary to mean anything.
    LOCK_FUNCTIONS = %w(
      nextval currval lastval get_lock release_lock is_free_lock is_used_lock
      pg_advisory_lock pg_advisory_unlock
    ).freeze

    # These are matched anywhere in the statement (hence `/m`, and no `\Z`
    # anchor): a locking clause is not always the final token on a single line.
    # `FOR UPDATE SKIP LOCKED`, `FOR UPDATE NOWAIT`, `FOR UPDATE OF t`, MySQL
    # 8's `FOR SHARE`, a trailing semicolon and multi-line formatting all have
    # to reach the primary, or the lock is taken on a replica nobody else
    # contends on and the application only believes it has mutual exclusion.
    SQL_PRIMARY_MATCHERS = [
      /\A\s*select\b.*\bfor\s+(update|share)\b/im,
      /\A\s*select\b.*\block\s+in\s+share\s+mode\b/im,
      /\A\s*select\b.*\b(#{LOCK_FUNCTIONS.join('|')})\s*\(/im,
      /\A\s*show\b/i,
    ].freeze
    SQL_REPLICA_MATCHERS = [/\A\s*(select|with.+\)\s*select)\s/i].freeze
    SQL_ALL_MATCHERS = [/\A\s*set\s/i].freeze
    SQL_SKIP_ALL_MATCHERS = [/\A\s*set\s+local\s/i].freeze

    # Leading whitespace and SQL comments are stripped before matching so that an
    # annotated statement (e.g. `/* app:web */ INSERT ...`) is classified by the
    # statement itself rather than by the comment.
    LEADING_NOISE = %r{\A(?:\s+|/\*.*?\*/|--[^\n]*(?:\n|\z)|\#[^\n]*(?:\n|\z))+}m

    def initialize(sql, open_transactions)
      @_sql = sql
      @_open_transactions = open_transactions
    end

    def where_to_send?
      if should_send_to_all?
        ALL
      elsif can_go_to_replica?
        REPLICA
      else
        PRIMARY
      end
    end

    private

    def should_send_to_all?
      match_any?(SQL_ALL_MATCHERS) && !match_any?(SQL_SKIP_ALL_MATCHERS)
    end

    # A replica may only serve a statement we positively recognise as a read and
    # that nothing else forces onto the primary. Everything we do not recognise
    # as a read defaults to the primary, which is the safe direction for a
    # write/read proxy: a misrouted read only costs a little primary load, while
    # a misrouted write is an error (or worse) against a read-only replica.
    #
    # Because this is only reached for a confirmed read, there is no need to also
    # test for a write here.
    def can_go_to_replica?
      read_query? && !should_go_to_primary?
    end

    def read_query?
      match_any?(SQL_REPLICA_MATCHERS)
    end

    def should_go_to_primary?
      Janus::Context.use_primary? ||
        @_open_transactions.positive? ||
        match_any?(SQL_PRIMARY_MATCHERS)
    end

    def match_any?(matchers)
      matchers.any? { |matcher| normalized_sql.match?(matcher) }
    end

    # Avoid copying the statement when there is no leading comment/whitespace to
    # strip, which is the common case for ActiveRecord-generated SQL.
    def normalized_sql
      @normalized_sql ||= strip_leading_noise
    end

    def strip_leading_noise
      return @_sql unless LEADING_NOISE.match?(@_sql)

      @_sql.sub(LEADING_NOISE, '')
    end
  end
end
