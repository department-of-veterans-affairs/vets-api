# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Flipper do
  describe 'envar usage in Flipper initializer ENV toggle' do
    describe 'FLIPPER_USE_RAKE_SETUP environment variable' do
      # NOTE: Testing the initializer behavior directly is challenging because
      # it runs at application boot time. These tests verify the conditional logic
      # that determines whether feature initialization should be skipped.

      describe 'ActiveModel::Type::Boolean casting' do
        # The initializer uses ActiveModel::Type::Boolean.new.cast() for safe parsing
        # NOTE: cast() returns nil for nil/empty string, which is falsy in Ruby

        it 'returns true for string "true"' do
          result = ActiveModel::Type::Boolean.new.cast('true')
          expect(result).to be true
        end

        it 'returns true for string "1"' do
          result = ActiveModel::Type::Boolean.new.cast('1')
          expect(result).to be true
        end

        it 'returns false for string "false"' do
          result = ActiveModel::Type::Boolean.new.cast('false')
          expect(result).to be false
        end

        it 'returns false for string "0"' do
          result = ActiveModel::Type::Boolean.new.cast('0')
          expect(result).to be false
        end

        it 'returns nil (falsy) for nil' do
          result = ActiveModel::Type::Boolean.new.cast(nil)
          expect(result).to be_nil
          expect(result).to be_falsy
        end

        it 'returns nil (falsy) for empty string' do
          result = ActiveModel::Type::Boolean.new.cast('')
          expect(result).to be_nil
          expect(result).to be_falsy
        end
      end

      describe 'ENV variable behavior' do
        around do |example|
          original_value = ENV.fetch('FLIPPER_USE_RAKE_SETUP', nil)
          example.run
        ensure
          if original_value.nil?
            ENV.delete('FLIPPER_USE_RAKE_SETUP')
          else
            ENV['FLIPPER_USE_RAKE_SETUP'] = original_value
          end
        end

        context 'when FLIPPER_USE_RAKE_SETUP is not set' do
          before { ENV.delete('FLIPPER_USE_RAKE_SETUP') }

          it 'ENV.fetch returns nil with nil default' do
            value = ENV.fetch('FLIPPER_USE_RAKE_SETUP', nil)
            expect(value).to be_nil
          end

          it 'boolean cast of nil is falsy' do
            value = ActiveModel::Type::Boolean.new.cast(ENV.fetch('FLIPPER_USE_RAKE_SETUP', nil))
            expect(value).to be_falsy
          end
        end

        context 'when FLIPPER_USE_RAKE_SETUP is "true"' do
          before { ENV['FLIPPER_USE_RAKE_SETUP'] = 'true' }

          it 'boolean cast returns true' do
            value = ActiveModel::Type::Boolean.new.cast(ENV.fetch('FLIPPER_USE_RAKE_SETUP', nil))
            expect(value).to be true
          end
        end

        context 'when FLIPPER_USE_RAKE_SETUP is "false"' do
          before { ENV['FLIPPER_USE_RAKE_SETUP'] = 'false' }

          it 'boolean cast returns false' do
            value = ActiveModel::Type::Boolean.new.cast(ENV.fetch('FLIPPER_USE_RAKE_SETUP', nil))
            expect(value).to be false
          end
        end

        context 'when FLIPPER_USE_RAKE_SETUP is "1"' do
          before { ENV['FLIPPER_USE_RAKE_SETUP'] = '1' }

          it 'boolean cast returns true' do
            value = ActiveModel::Type::Boolean.new.cast(ENV.fetch('FLIPPER_USE_RAKE_SETUP', nil))
            expect(value).to be true
          end
        end
      end
    end
  end
end
