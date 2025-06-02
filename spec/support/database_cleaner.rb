# frozen_string_literal: true

class DirtyDatabaseError < RuntimeError
  def initialize(meta)
    super "#{meta[:full_description]}\n\t#{meta[:location]}"
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    if defined?(ParallelTests) && ParallelTests.first_process?
      DatabaseCleaner.clean_with(:deletion)
    end
  end

  config.before(:all, :cleaner_for_context) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.before do |example|
    next if example.metadata[:cleaner_for_context]

    DatabaseCleaner.strategy =
      if example.metadata[:js]
        :truncation
      else
        example.metadata[:strategy] || :transaction
      end

    DatabaseCleaner.start
  end

  config.after do |example|
    next if example.metadata[:cleaner_for_context]

    DatabaseCleaner.clean

    # raise DirtyDatabaseError.new(example.metadata) if Record.count > 0
  end

  config.after(:all, :cleaner_for_context) do
    DatabaseCleaner.clean
  end
end
