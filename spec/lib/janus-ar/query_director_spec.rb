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

    it { expect(described_class::ALL).to eq :all }
    it { expect(described_class::REPLICA).to eq :replica }
    it { expect(described_class::PRIMARY).to eq :primary }
  end

  describe '#where_to_send?' do
    let(:open_transactions) { 0 }

    before(:each) { Janus::Context.release_all }

    context 'with reads' do
      {
        'plain select' => 'SELECT * FROM users',
        'lower case select' => 'select * from users',
        'CTE select' => 'WITH recent AS (SELECT * FROM users) SELECT * FROM recent',
        'leading whitespace' => "\n\t  SELECT 1",
      }.each do |label, query|
        it "routes a #{label} to the replica" do
          expect(described_class.new(query, 0).where_to_send?).to eq(:replica)
        end
      end
    end

    context 'with writes' do
      # Every one of these used to be sent to the replica because the router
      # defaulted unknown statements there. They are genuine writes and must
      # reach the primary.
      %w(
        INSERT UPDATE DELETE REPLACE RENAME CALL LOAD OPTIMIZE ANALYZE REPAIR
        CREATE DROP TRUNCATE ALTER
      ).each do |verb|
        it "routes #{verb} to the primary" do
          sql = "#{verb} something that is not a read"
          expect(described_class.new(sql, 0).where_to_send?).to eq(:primary)
        end
      end

      it 'routes a write annotated with a leading comment to the primary' do
        sql = '/* app:web,controller:orders */ INSERT INTO orders (id) VALUES (1)'
        expect(described_class.new(sql, 0).where_to_send?).to eq(:primary)
      end

      it 'routes a read annotated with a leading comment to the replica' do
        sql = '/* app:web */ SELECT * FROM orders'
        expect(described_class.new(sql, 0).where_to_send?).to eq(:replica)
      end
    end

    context 'with locking reads' do
      it 'routes SELECT ... FOR UPDATE to the primary' do
        expect(described_class.new('SELECT * FROM users FOR UPDATE', 0).where_to_send?).to eq(:primary)
      end

      it 'routes SELECT ... LOCK IN SHARE MODE to the primary' do
        expect(described_class.new('SELECT * FROM users LOCK IN SHARE MODE', 0).where_to_send?).to eq(:primary)
      end

      it 'routes advisory lock reads to the primary' do
        expect(described_class.new("SELECT get_lock('x', 0)", 0).where_to_send?).to eq(:primary)
      end
    end

    context 'with SHOW' do
      it 'routes SHOW statements to the primary' do
        expect(described_class.new('SHOW TABLES', 0).where_to_send?).to eq(:primary)
      end
    end

    context 'with SET' do
      it 'routes SET to all connections' do
        expect(described_class.new('SET sql_mode = ?', 0).where_to_send?).to eq(:all)
      end

      it 'does not broadcast SET LOCAL to all connections' do
        expect(described_class.new('SET LOCAL sql_mode = ?', 0).where_to_send?).to eq(:primary)
      end
    end

    context 'when the context is stuck to the primary' do
      before(:each) { Janus::Context.stick_to_primary }

      it 'routes an otherwise replica-bound read to the primary' do
        expect(described_class.new('SELECT * FROM users', 0).where_to_send?).to eq(:primary)
      end
    end

    context 'when inside a transaction' do
      let(:open_transactions) { 1 }

      it 'routes reads to the primary so they can see uncommitted writes' do
        expect(described_class.new('SELECT * FROM users', open_transactions).where_to_send?).to eq(:primary)
      end
    end

    context 'with an unrecognised / empty statement' do
      it 'defaults blank input to the primary' do
        expect(described_class.new('   ', 0).where_to_send?).to eq(:primary)
      end
    end
  end
end
