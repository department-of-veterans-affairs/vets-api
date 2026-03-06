# frozen_string_literal: true

require 'rubocop'
require_relative '../../../../lib/rubocop/cop/sre/no_module_frameworks'
require_relative 'sre_cop_spec_helper'

RSpec.describe RuboCop::Cop::Sre::NoModuleFrameworks do
  include SreCopSpecHelper

  subject(:cop) { described_class.new }

  describe 'framework classes in modules' do
    it 'registers an offense for ErrorHandler class in modules dir' do
      offenses = inspect_source(<<~RUBY, 'modules/my_module/app/services/error_handler.rb')
        class MyModule::ErrorHandler
          def call(error)
            # handle
          end
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('ErrorHandler')
    end

    it 'registers an offense for LogService class in modules dir' do
      offenses = inspect_source(<<~RUBY, 'modules/my_module/app/services/log_service.rb')
        class LogService
          def log(msg)
            # log
          end
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('LogService')
    end
  end

  describe 'framework methods in modules' do
    it 'registers an offense for handle_error method in modules dir' do
      offenses = inspect_source(<<~RUBY, 'modules/my_module/app/controllers/base_controller.rb')
        def handle_error(e)
          log(e)
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('handle_error')
    end

    it 'registers an offense for handle_exception method in modules dir' do
      offenses = inspect_source(<<~RUBY, 'modules/my_module/app/controllers/base_controller.rb')
        def handle_exception(e)
          log(e)
        end
      RUBY
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include('[Play 10]')
      expect(offenses.first.message).to include('handle_exception')
    end
  end

  describe 'allowed patterns' do
    it 'does not register an offense for ErrorHandler outside modules dir' do
      expect_no_offenses(<<~RUBY, 'app/services/error_handler.rb')
        class MyModule::ErrorHandler
          def call(error)
            # handle
          end
        end
      RUBY
    end

    it 'does not register an offense for a normal method name in modules dir' do
      expect_no_offenses(<<~RUBY, 'modules/my_module/app/services/processor.rb')
        def process_data
          # work
        end
      RUBY
    end
  end
end
