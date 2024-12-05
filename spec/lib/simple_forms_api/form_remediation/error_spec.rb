# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../lib/simple_forms_api/form_remediation/error'

RSpec.describe SimpleFormsApi::FormRemediation::Error do
  let(:default_message) { 'An error occurred during the form remediation process' }
  let(:custom_message) { 'Custom error occurred' }
  let(:details_hash) { { message: 'Detailed error description' } }
  let(:backtrace_array) { ['/path/to/file.rb:42:in `method_name`'] }
  let(:base_error) { StandardError.new('Base error message') }

  describe '#initialize' do
    subject(:instance) do
      described_class.new(message: custom_message, error: base_error, details: details_hash, backtrace: backtrace_array)
    end

    it 'sets the custom message' do
      expect(instance.message).to include(custom_message)
    end

    it 'sets the base error' do
      expect(instance.base_error).to eq(base_error)
    end

    it 'sets the details' do
      expect(instance.details).to eq(details_hash)
    end

    it 'sets the custom backtrace' do
      expect(instance.backtrace).to eq(backtrace_array)
    end
  end

  describe '#message' do
    subject(:message) { instance.message }

    context 'when initialized with default values' do
      let(:instance) { described_class.new }

      it 'returns the default error message' do
        expect(message).to eq(default_message)
      end
    end

    context 'when initialized with a custom message' do
      let(:instance) { described_class.new(message: custom_message) }

      it 'returns the custom message' do
        expect(message).to eq(custom_message)
      end
    end

    context 'when initialized with details containing a message' do
      let(:instance) { described_class.new(details: details_hash) }

      it 'includes the details message in the error message' do
        expect(message).to include(details_hash[:message])
      end
    end

    context 'when initialized with a base error' do
      let(:instance) { described_class.new(error: base_error) }

      it 'includes the base error message in the error message' do
        expect(message).to include(base_error.message)
      end
    end
  end

  describe '#backtrace' do
    subject(:backtrace) { instance.backtrace }

    context 'when initialized with a custom backtrace' do
      let(:instance) { described_class.new(backtrace: backtrace_array) }

      it 'returns the custom backtrace' do
        expect(backtrace).to eq(backtrace_array)
      end
    end

    context 'when initialized with a base error containing a backtrace' do
      let(:base_error) do
        StandardError.new.tap do |e|
          e.set_backtrace(['/path/to/another_file.rb:50:in `another_method`'])
        end
      end
      let(:instance) { described_class.new(error: base_error) }

      it 'returns the base error backtrace' do
        expect(backtrace).to eq(base_error.backtrace)
      end
    end

    context 'when no backtrace is provided' do
      let(:instance) { described_class.new }

      it 'returns the default backtrace' do
        expect(backtrace).to be_nil
      end
    end
  end

  describe '#base_error' do
    subject(:base_error) { instance.base_error }

    context 'when initialized with a base error' do
      let(:instance) { described_class.new(error: StandardError.new('Base error')) }

      it 'returns the base error' do
        expect(base_error.message).to eq('Base error')
      end
    end

    context 'when no base error is provided' do
      let(:instance) { described_class.new }

      it 'returns nil' do
        expect(base_error).to be_nil
      end
    end
  end

  describe '#details' do
    subject(:details) { instance.details }

    context 'when initialized with details' do
      let(:instance) { described_class.new(details: details_hash) }

      it 'returns the details' do
        expect(details).to eq(details_hash)
      end
    end

    context 'when no details are provided' do
      let(:instance) { described_class.new }

      it 'returns nil' do
        expect(details).to be_nil
      end
    end
  end
end
