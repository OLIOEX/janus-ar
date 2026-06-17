# frozen_string_literal: true

# Expects the including context to provide `failover_config` and
# `no_failover_config`, both pointing at a healthy primary and an unreachable
# replica.
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
