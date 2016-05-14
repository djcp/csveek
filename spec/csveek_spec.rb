require 'rspec'
require './lib/csveek'
require 'pry'

RSpec.describe Csveek do
  describe '#load' do
    it 'throws an error if the csv file does not exist' do
      csveek = described_class.new
      expect {
        csveek.load_file('not_there.csv')
      }.to raise_error(Errno::ENOENT)
    end

    it 'parses a csv file a line at a time' do
      db_file = 'databases/sample.db'
      with_cleaned_database_file(db_file) do
        csveek = described_class.new
        allow(CSV).to receive(:foreach)

        csveek.load_file('spec/support/sample.csv')

        expect(CSV).to have_received(:foreach)
      end
    end

    it 'creates an sqlite database if it does not exist' do
      db_file = 'databases/sample.db'
      with_cleaned_database_file(db_file) do

        csveek = described_class.new
        csveek.load_file('spec/support/sample.csv')

        expect(File.exist?(db_file)).to be true
      end
    end

    it 'creates columns from the first row' do
      db_file = 'databases/sample.db'
      csv_file = 'spec/support/sample.csv'
      with_cleaned_database_file(db_file) do
        csveek = described_class.new
        csveek.load_file(csv_file)

        columns_from_db = csveek.connection.execute('PRAGMA table_info(data)').map{|col| col[1]}
        expect(columns_from_db).to match_array(columns_from_csv(csv_file))
      end
    end
  end

  describe "#by_age" do
    it 'sorts rows correctly by age' do
      db_file = 'databases/sample.db'
      csv_file = 'spec/support/sample.csv'
      #mystery guest data
      expected_data = %Q|Matt Conway, age: 22
David Block, age: 76
Rob May, age: 
|
      with_cleaned_database_file(db_file) do
        csveek = described_class.new
        expect{csveek.by_age(csv_file)}.to output(expected_data).to_stdout
      end
    end
  end

  describe "#find_last_name" do
    it 'sorts rows by name' do
      db_file = 'databases/sample.db'
      csv_file = 'spec/support/sample.csv'
      #mystery guest data
      expected_data = %Q|Matt Conway, age: 22
|
      with_cleaned_database_file(db_file) do
        csveek = described_class.new
        expect{csveek.find_last_name(csv_file, 'Conway')}.to output(expected_data).to_stdout
      end
    end
  end

  def columns_from_csv(csv_file)
    cols = []
    CSV.foreach(csv_file, {headers: :first_row, header_converters: :symbol}) do |row|
      # this technically inefficient
      cols = row.map{|stuff| stuff[0].to_s}
    end
    cols
  end

  def with_cleaned_database_file(db_file)
    File.unlink(db_file) if File.exist?(db_file)
    yield
    File.unlink(db_file) if File.exist?(db_file)
  end
end
