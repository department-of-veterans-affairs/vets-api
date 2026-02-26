# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/rubocop/cop/sre/no_module_frameworks'

RSpec.describe RuboCop::Cop::Sre::NoModuleFrameworks, :config do
  subject(:cop) { described_class.new }

  def inspect_source_file(source, file_path)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
    commissioner = RuboCop::Cop::Commissioner.new([cop])
    commissioner.investigate(processed_source)
    cop.offenses
  end

  describe 'framework classes in modules' do
    it 'registers an offense for ErrorHandler class in modules dir' do
      source = <<~RUBY
        class MyModule::ErrorHandler
          def call(error)
            # handle
          end
        end
      RUBY
      offenses = inspect_source_file(source, 'modules/my_module/app/services/error_handler.rb')
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('ErrorHandler')
    end

    it 'registers an offense for LogService class in modules dir' do
      source = <<~RUBY
        class LogService
          def log(msg)
            # log
          end
        end
      RUBY
      offenses = inspect_source_file(source, 'modules/my_module/app/services/log_service.rb')
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('LogService')
    end
  end

  describe 'framework methods in modules' do
    it 'registers an offense for handle_error method in modules dir' do
      source = <<~RUBY
        def handle_error(e)
          log(e)
        end
      RUBY
      offenses = inspect_source_file(source, 'modules/my_module/app/controllers/base_controller.rb')
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('handle_error')
    end

    it 'registers an offense for handle_exception method in modules dir' do
      source = <<~RUBY
        def handle_exception(e)
          log(e)
        end
      RUBY
      offenses = inspect_source_file(source, 'modules/my_module/app/controllers/base_controller.rb')
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('handle_exception')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for ErrorHandler outside modules dir' do
      source = <<~RUBY
        class MyModule::ErrorHandler
          def call(error)
            # handle
          end
        end
      RUBY
      offenses = inspect_source_file(source, 'app/services/error_handler.rb')
      expect(offenses).to be_empty
    end

    it 'does not register an offense for a normal method name in modules dir' do
      source = <<~RUBY
        def process_data
          # work
        end
      RUBY
      offenses = inspect_source_file(source, 'modules/my_module/app/services/processor.rb')
      expect(offenses).to be_empty
    end
  end
end
