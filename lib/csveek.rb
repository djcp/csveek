require 'thor'
require 'csv'
require 'sqlite3'

class Csveek < Thor
  attr_reader :connection

  desc 'load_file FILE', 'load FILE into a sqlite database. Run automatically by the other commands'
  def load_file(file)
    # This could probably be run on initialize
    first_row = []
    @db_path = db_path_from_file(file)
    unless database_exists?
      CSV.foreach(file, {headers: :first_row, header_converters: :symbol}) do |row|
        create_database(row)
        load_row(row)
      end
    end
    get_connection
  end

  desc 'find_last_name FILE LAST_NAME', 'load FILE and print records that match LAST_NAME'
  def find_last_name(file, last_name)
    # This runs case sensitive queries, which could be fixed
    load_file(file)

    get_connection.query('select * from data where last = ?', [last_name]).each_hash do |row|
      puts %Q|#{row['first']} #{row['last']}, age: #{row['age']}|
    end
  end

  desc 'by_age FILE', 'load FILE and print records by age'
  def by_age(file)
    load_file(file)

    # hopefully no one is older than 10000 years. Cast age to int
    get_connection.query('select * from data order by ifnull(age, 10000) + 0').each_hash do |row|
      puts %Q|#{row['first']} #{row['last']}, age: #{row['age']}|
    end
  end

  private

  def db_path_from_file(file)
    './databases/' + File.basename(file, '.*').gsub(/[^a-z\d]/i,'') + '.db'
  end

  def database_exists?
    File.exists?(@db_path)
  end

  def create_database(row)
    return if database_exists?
    columns = row.map{|stuff| stuff[0]}
    # We could guess on types here
    row_create_statements = columns.map{|column| "#{column} varchar(1000)"}

    get_connection.execute(%Q|create table data( #{row_create_statements.join(',')} )|)
    create_indexes_on_columns(columns)
  end

  def create_indexes_on_columns(columns)
    columns.each do |column|
      get_connection.execute(%Q|create index #{column}_idx on data(#{column})|)
    end
  end

  def get_connection
    @connection ||= SQLite3::Database.new(@db_path)
  end

  def load_row(row)
    columns = []
    values = []
    row.each do |column, value|
      columns << column
      values << value
    end

    get_connection.execute(
      %Q|INSERT INTO data(#{columns.join(',')}) values(#{columns.map{'?'}.join(',')})|,
      values
    )
  end
end
