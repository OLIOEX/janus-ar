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
end
