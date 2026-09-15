# frozen_string_literal: true
RSpec.shared_examples 'a postgres like server' do
  let(:quoted_table) { %("#{table_name}") }
  let(:create_test_table) do
    ActiveRecord::Base.connection.execute(
      "CREATE TABLE #{quoted_table} (id SERIAL PRIMARY KEY, name VARCHAR(255))"
    )
  end
  let(:list_tables) do
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
  end
  let(:model) do
    name = table_name
    Class.new(ActiveRecord::Base) do
      self.table_name = name

      # Anonymous classes have no `name`, which ActiveRecord needs for
      # validation messages and inspection.
      def self.name
        'JanusPostgresRecord'
      end
    end
  end

  before(:each) do
    $query_logger.flush_all
    ActiveRecord::Base.establish_connection(config)
  end

  after(:each) do
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{quoted_table}")
  end

  it 'can list tables' do
    expect(ActiveRecord::Base.connection.execute(list_tables).to_a).to eq []
  end

  it 'can create table' do
    create_test_table
    expect(ActiveRecord::Base.connection.execute(list_tables).to_a).to eq [{ 'tablename' => table_name }]
  end

  describe 'SELECT' do
    it 'reads from `replica` by default' do
      create_test_table
      Janus::Context.release_all
      $query_logger.flush_all
      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}")
      expect($query_logger.queries.first).to include '[replica]'
    end

    it 'will read from primary after a write operation' do
      create_test_table
      $query_logger.flush_all
      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}")
      expect($query_logger.queries.first).to include '[primary]'
    end
  end

  describe 'INSERT' do
    let(:insert_query) { "INSERT INTO #{quoted_table} (id) VALUES (5)" }

    before(:each) do
      create_test_table
      $query_logger.flush_all
      Janus::Context.release_all
    end

    it 'sends INSERT query to primary' do
      ActiveRecord::Base.connection.execute(insert_query)
      expect($query_logger.queries.first).to include '[primary]'
    end

    it 'ignores case when directing queries' do
      ActiveRecord::Base.connection.execute(insert_query.downcase)
      expect($query_logger.queries.first).to include '[primary]'
    end
  end

  describe 'UPDATE' do
    before(:each) do
      create_test_table
      5.times { |i| ActiveRecord::Base.connection.execute("INSERT INTO #{quoted_table} (id) VALUES (#{i})") }
      $query_logger.flush_all
      Janus::Context.release_all
    end

    it 'continues to direct after bulk update' do
      ActiveRecord::Base.connection.execute("UPDATE #{quoted_table} SET id = id + 20")
      expect($query_logger.queries.first).to include '[primary]'
      expect(Janus::Context.last_used_connection).to eq :primary
      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}")
      expect($query_logger.queries.last).to include '[primary]'
      Janus::Context.release_all
      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}")
      expect($query_logger.queries.last).to include '[replica]'
      expect(Janus::Context.last_used_connection).to eq :replica
    end
  end

  describe 'ActiveRecord compatibility' do
    before(:each) do
      create_test_table
      Janus::Context.release_all
    end

    it 'accepts the optional name argument on #execute' do
      expect do
        ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}", 'CustomName')
      end.not_to raise_error
    end

    it 'returns a usable result through the exec_query read path' do
      ActiveRecord::Base.connection.execute("INSERT INTO #{quoted_table} (id) VALUES (7)")
      Janus::Context.release_all
      $query_logger.flush_all

      result = ActiveRecord::Base.connection.exec_query("SELECT id FROM #{quoted_table}")

      expect(result.rows).to eq [[7]]
      expect($query_logger.queries.first).to include '[replica]'
    end
  end

  # PostgreSQL never inlines bind values the way the MySQL adapters do: the
  # statement reaches the adapter as `$1` placeholders with the values alongside
  # it. A replica that is handed the SQL alone therefore fails with
  # "there is no parameter $1", so these cover the full ActiveRecord stack
  # rather than raw `execute` calls.
  describe 'Bind parameters' do
    before(:each) do
      create_test_table
      model.reset_column_information
      model.create!(name: 'janus')
      Janus::Context.release_all
      $query_logger.flush_all
    end

    it 'serves a parameterised read from the replica' do
      record = model.find_by(name: 'janus')

      expect(record.name).to eq 'janus'
      expect($query_logger.queries.last).to include '[replica]'
    end

    it 'serves a repeated parameterised read from the replica' do
      2.times { model.where(name: 'janus').to_a }

      expect(model.where(name: 'janus').pluck(:name)).to eq %w(janus)
      expect($query_logger.queries.last).to include '[replica]'
    end

    it 'sends a parameterised write to the primary' do
      model.where(name: 'janus').update_all(name: 'renamed')

      expect($query_logger.queries.last).to include '[primary]'
      expect(model.pluck(:name)).to eq %w(renamed)
    end
  end

  describe 'Locking reads' do
    before(:each) do
      create_test_table
      Janus::Context.release_all
      $query_logger.flush_all
    end

    it 'sends a FOR UPDATE SKIP LOCKED claim to the primary' do
      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table} LIMIT 1 FOR UPDATE SKIP LOCKED")
      expect($query_logger.queries.last).to include '[primary]'
    end

    it 'sends a FOR NO KEY UPDATE read to the primary' do
      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table} FOR NO KEY UPDATE")
      expect($query_logger.queries.last).to include '[primary]'
    end

    it 'sends a multi-line locking read to the primary' do
      ActiveRecord::Base.connection.execute("SELECT *\nFROM #{quoted_table}\nWHERE id = 1\nFOR UPDATE")
      expect($query_logger.queries.last).to include '[primary]'
    end

    it 'sends an advisory lock read to the primary' do
      ActiveRecord::Base.connection.execute('SELECT pg_try_advisory_lock(1)')
      expect($query_logger.queries.last).to include '[primary]'
      ActiveRecord::Base.connection.execute('SELECT pg_advisory_unlock_all()')
    end
  end

  describe 'Transactions' do
    before(:each) do
      create_test_table
      Janus::Context.release_all
      $query_logger.flush_all
    end

    it 'routes reads inside a transaction to the primary' do
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}")
      end

      selects = $query_logger.queries.select { |q| q.downcase.include?("select * from \"#{table_name}\"") }
      expect(selects).not_to be_empty
      expect(selects).to all(include('[primary]'))
    end

    it 'keeps later reads on the primary until the context is released' do
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("INSERT INTO #{quoted_table} (id) VALUES (1)")
      end
      $query_logger.flush_all

      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}")
      expect($query_logger.queries.last).to include '[primary]'

      Janus::Context.release_all
      ActiveRecord::Base.connection.execute("SELECT * FROM #{quoted_table}")
      expect($query_logger.queries.last).to include '[replica]'
    end
  end

  describe 'SET statements' do
    before(:each) { Janus::Context.release_all }

    it 'sends a session SET down the broadcast (:all) path without error' do
      expect do
        ActiveRecord::Base.connection.execute("SET SESSION TIME ZONE 'UTC'")
      end.not_to raise_error

      # `:all` means the statement ran against the replica connection too, not
      # just the primary - a write would have been marked `:primary`.
      expect(Janus::Context.last_used_connection).to eq :all
    end
  end
end
