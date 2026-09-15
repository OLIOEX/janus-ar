# frozen_string_literal: true

RSpec.describe ActiveRecord::ConnectionAdapters::JanusPostgreSQLAdapter do
  subject { described_class.new(config) }

  let(:database) { 'test' }
  let(:primary_config) do
    {
      'username' => 'janus_primary',
      'password' => 'primary_password',
      'host' => '127.0.0.1',
      'port' => 5432,
    }
  end
  let(:replica_config) do
    {
      'username' => 'janus_replica',
      'password' => 'replica_password',
      'host' => '127.0.0.1',
      'port' => 5432,
      'pool' => 500,
    }
  end
  let(:config) do
    {
      database:,
      adapter: 'janus_postgresql',
      janus: {
        'primary' => primary_config,
        'replica' => replica_config,
      },
    }
  end

  describe 'Configuration' do
    it 'creates primary connection as expected' do
      config = primary_config.dup.freeze
      expect(subject.config).to eq config.merge('database' => database).symbolize_keys
    end

    it 'creates replica connection as expected' do
      config = replica_config.dup.freeze
      expect(
        subject.replica_connection.instance_variable_get(:@config)
      ).to eq config.merge('database' => database).symbolize_keys
    end

    it 'builds the replica as a plain PostgreSQL adapter' do
      expect(subject.replica_connection).to be_an_instance_of(
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      )
    end

    context 'Rails sets empty database for server connection' do
      let(:database) { nil }

      it 'creates primary connection as expected' do
        config = primary_config.dup.freeze
        expect(subject.config).to eq config.merge('database' => nil).symbolize_keys
      end

      it 'creates replica connection as expected' do
        config = replica_config.dup.freeze
        expect(
          subject.replica_connection.instance_variable_get(:@config)
        ).to eq config.merge('database' => nil).symbolize_keys
      end
    end
  end

  # The regression this guards: `raw_execute` used to replay the bare SQL on the
  # replica, which on PostgreSQL means handing it `$1` placeholders and no
  # parameters. The fake below stands in for the replica adapter so we can assert
  # on the full argument list without needing a live server.
  describe 'Bind parameter forwarding' do
    let(:fake_replica) do
      Class.new do
        attr_reader :calls

        def initialize
          @calls = []
        end

        def raw_execute(*args, **kwargs)
          @calls << [args, kwargs]
        end
      end.new
    end

    before do
      allow(subject).to receive(:replica_connection).and_return(fake_replica)
      Janus::Context.release_all
    end

    it 'passes the name, binds and prepare flag through to the replica' do
      sql = 'SELECT * FROM users WHERE id = $1'

      subject.raw_execute(sql, 'SQL', [1], prepare: true)

      expect(fake_replica.calls).to eq [[[sql, 'SQL', [1]], { prepare: true }]]
    end
  end

  describe 'Connection lifecycle' do
    let(:replica_adapter_class) { ActiveRecord::ConnectionAdapters::PostgreSQLAdapter }

    it_behaves_like 'an adapter forwarding lifecycle calls'
  end

  describe 'Integration tests' do
    let(:table_name) { 'table_name_postgresql' }

    it_behaves_like 'a postgres like server'
  end
end
