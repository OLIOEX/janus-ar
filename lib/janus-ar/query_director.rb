# frozen_string_literal: true
module Janus
  class QueryDirector
    ALL = :all
    REPLICA = :replica
    PRIMARY = :primary

    SQL_PRIMARY_MATCHERS = [
      /\A\s*select.+for update\Z/i, /select.+lock in share mode\Z/i,
      /\A\s*select.+(nextval|currval|lastval|get_lock|release_lock|pg_advisory_lock|pg_advisory_unlock)\(/i,
      /\A\s*show/i
    ].freeze
    SQL_REPLICA_MATCHERS = [/\A\s*(select|with.+\)\s*select)\s/i].freeze
    SQL_ALL_MATCHERS = [/\A\s*set\s/i].freeze
    SQL_SKIP_ALL_MATCHERS = [/\A\s*set\s+local\s/i].freeze
    WRITE_PREFIXES = %w(INSERT UPDATE DELETE LOCK CREATE GRANT DROP ALTER TRUNCATE BEGIN SAVEPOINT FLUSH).freeze

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
      SQL_ALL_MATCHERS.any? { |matcher| @_sql =~ matcher } && SQL_SKIP_ALL_MATCHERS.none? { |matcher| @_sql =~ matcher }
    end

    def can_go_to_replica?
      !should_go_to_primary?
    end

    def should_go_to_primary?
      Janus::Context.use_primary? ||
        write_query? ||
        @_open_transactions.positive? ||
        SQL_PRIMARY_MATCHERS.any? { |matcher| @_sql =~ matcher }
    end

    def write_query?
      WRITE_PREFIXES.include?(@_sql.upcase.split(' ').first)
    end
  end
end
