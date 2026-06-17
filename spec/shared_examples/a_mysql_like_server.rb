# frozen_string_literal: true
RSpec.shared_examples 'a mysql like server' do
  let(:create_test_table) { ActiveRecord::Base.connection.execute("CREATE TABLE `#{table_name}` (id INT);") }

  before(:each) do
    $query_logger.flush_all
    ActiveRecord::Base.establish_connection(config)
  end

  after(:each) do
    ActiveRecord::Base.connection.execute(<<-SQL
      SELECT CONCAT('DROP TABLE IF EXISTS `', table_name, '`;')
      FROM information_schema.tables
      WHERE table_schema = '#{database}';
      SQL
                                         ).to_a.map { |row| ActiveRecord::Base.connection.execute(row[0]) }
  end

  it 'can list tables' do
    expect(ActiveRecord::Base.connection.execute('SHOW TABLES;').to_a).to eq []
  end

  it 'can create table' do
    create_test_table
    expect(ActiveRecord::Base.connection.execute('SHOW TABLES;').to_a).to eq [[table_name]]
  end

  describe 'SELECT' do
    it 'reads from `replica` by default' do
      create_test_table
      Janus::Context.release_all
      $query_logger.flush_all
      ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;")
      expect($query_logger.queries.first).to include '[replica]'
    end

    it 'will read from primary after a write operation' do
      create_test_table
      $query_logger.flush_all
      ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;")
      expect($query_logger.queries.first).to include '[primary]'
    end
  end

  describe 'INSERT' do
    let(:insert_query) { "INSERT INTO `#{table_name}` SET `id` = 5;" }

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
      5.times { |i| ActiveRecord::Base.connection.execute("INSERT INTO `#{table_name}` SET `id` = #{i};") }
      $query_logger.flush_all
      Janus::Context.release_all
    end

    it 'continues to direct after bulk update' do
      ActiveRecord::Base.connection.execute("UPDATE `#{table_name}` SET `id` = `id` + 2;")
      expect($query_logger.queries.first).to include '[primary]'
      expect(Janus::Context.last_used_connection).to eq :primary
      ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;")
      expect($query_logger.queries.last).to include '[primary]'
      Janus::Context.release_all
      ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;")
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
        ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;", 'CustomName')
      end.not_to raise_error
    end

    it 'returns a usable result through the exec_query read path' do
      ActiveRecord::Base.connection.execute("INSERT INTO `#{table_name}` SET `id` = 7;")
      Janus::Context.release_all
      $query_logger.flush_all

      result = ActiveRecord::Base.connection.exec_query("SELECT `id` FROM `#{table_name}`")

      expect(result.rows).to eq [[7]]
      expect($query_logger.queries.first).to include '[replica]'
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
        ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;")
      end

      selects = $query_logger.queries.select { |q| q.downcase.include?("select * from `#{table_name}`") }
      expect(selects).not_to be_empty
      expect(selects).to all(include('[primary]'))
    end

    it 'keeps later reads on the primary until the context is released' do
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("INSERT INTO `#{table_name}` SET `id` = 1;")
      end
      $query_logger.flush_all

      ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;")
      expect($query_logger.queries.last).to include '[primary]'

      Janus::Context.release_all
      ActiveRecord::Base.connection.execute("SELECT * FROM `#{table_name}`;")
      expect($query_logger.queries.last).to include '[replica]'
    end
  end

  describe 'SET statements' do
    before(:each) { Janus::Context.release_all }

    it 'sends a session SET down the broadcast (:all) path without error' do
      expect do
        ActiveRecord::Base.connection.execute("SET SESSION time_zone = '+00:00'")
      end.not_to raise_error

      # `:all` means the statement ran against the replica connection too, not
      # just the primary - a write would have been marked `:primary`.
      expect(Janus::Context.last_used_connection).to eq :all
    end
  end
end
