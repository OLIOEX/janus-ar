# frozen_string_literal: true

# Expects the including context to provide:
#   * `failover_config`         - healthy primary, unreachable replica, failover ON
#   * `no_failover_config`      - healthy primary, unreachable replica, failover OFF
#   * `healthy_failover_config` - healthy primary and replica, failover ON
RSpec.shared_examples 'a failover capable server' do
  before(:each) { Janus::Context.release_all }

  context 'when replica_failover is enabled' do
    it 'serves an otherwise replica-bound read from the primary' do
      ActiveRecord::Base.establish_connection(failover_config)
      # Warm up the primary so its connection-setup runs before we assert.
      ActiveRecord::Base.connection.execute('SELECT 1')
      Janus::Context.release_all

      result = ActiveRecord::Base.connection.exec_query('SELECT 1 AS one')

      expect(result.rows).to eq [[1]]
      expect(Janus::Context.last_used_connection).to eq :primary
    end

    it 'still applies a broadcast SET on the primary when the replica is down' do
      ActiveRecord::Base.establish_connection(failover_config)
      Janus::Context.release_all

      expect do
        ActiveRecord::Base.connection.execute("SET SESSION time_zone = '+00:00'")
      end.not_to raise_error
    end

    it 'does not swallow a genuine query error from a healthy replica' do
      ActiveRecord::Base.establish_connection(healthy_failover_config)
      Janus::Context.release_all

      expect do
        ActiveRecord::Base.connection.exec_query('SELECT * FROM a_table_that_does_not_exist')
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  context 'when replica_failover is disabled' do
    it 'lets the replica connection error surface' do
      ActiveRecord::Base.establish_connection(no_failover_config)
      Janus::Context.release_all

      expect { ActiveRecord::Base.connection.exec_query('SELECT 1 AS one') }.to raise_error do |error|
        expect(Janus::AdapterExtensions::REPLICA_FAILOVER_ERRORS.any? { |klass| error.is_a?(klass) }).to be true
      end
    end
  end
end
