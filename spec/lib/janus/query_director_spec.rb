# frozen_string_literal: true

RSpec.describe Janus::QueryDirector do
  describe 'Constants' do
    it { expect(described_class::SQL_SKIP_ALL_MATCHERS).to eq [/\A\s*set\s+local\s/i] }
    it {
      expect(described_class::SQL_PRIMARY_MATCHERS).to eq(
        [
          /\A\s*select.+for update\Z/i, /select.+lock in share mode\Z/i,
          /\A\s*select.+(nextval|currval|lastval|get_lock|release_lock|pg_advisory_lock|pg_advisory_unlock)\(/i,
          /\A\s*show/i
        ]
      )
    }
    it { expect(described_class::SQL_REPLICA_MATCHERS).to eq([/\A\s*(select|with.+\)\s*select)\s/i]) }
    it { expect(described_class::SQL_ALL_MATCHERS).to eq([/\A\s*set\s/i]) }
    it {
      expect(described_class::WRITE_PREFIXES).to eq %w(INSERT UPDATE DELETE LOCK CREATE GRANT DROP ALTER TRUNCATE FLUSH)
    }

    it { expect(described_class::ALL).to eq :all }
    it { expect(described_class::REPLICA).to eq :replica }
    it { expect(described_class::PRIMARY).to eq :primary }
  end

  describe '#where_to_send?' do
    before(:each) do
      Janus::Context.release_all
    end

    context 'when should send to all' do
      it 'returns :all' do
        sql = 'SET foo = bar'
        open_transactions = 0
        query_director = described_class.new(sql, open_transactions)
        expect(query_director.where_to_send?).to eq(:all)
      end
    end

    context 'when can go to replica' do
      it 'returns :replica' do
        sql = 'SELECT * FROM users'
        open_transactions = 0
        query_director = described_class.new(sql, open_transactions)
        expect(query_director.where_to_send?).to eq(:replica)
      end
    end

    context 'when should go to primary' do
      it 'returns :primary' do
        sql = 'INSERT INTO users (name) VALUES ("John")'
        open_transactions = 0
        query_director = described_class.new(sql, open_transactions)
        expect(query_director.where_to_send?).to eq(:primary)
      end
    end
  end
end
