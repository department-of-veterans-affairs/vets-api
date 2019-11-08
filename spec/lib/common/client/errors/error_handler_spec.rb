# frozen_string_literal: true

require 'spec_helper'

describe Common::Client::Errors::ErrorHandler do
  let(:internal_server_error) { Common::Exceptions::InternalServerError }

  describe '#log_error' do
    subject { described_class.new(internal_server_error) }

    xit 'calls the super class' do
      allow_any_instance_of(SentryLogging).to receive(:log_error).and_return(true)
      expect(subject.log_error).to be(true)
    end

    context 'when ancestor does not implement `#log_error`' do
      xit 'raises a NotImplementedError' do
        expect(subject.log_error).to raise_error(NotImplementedError)
        pending 'this logic is not yet implemented'
      end
    end
  end

  describe '#transformed_error' do
    subject { described_class.new(StandardError.new).transformed_error }

    context 'when given an error without a specific counterpart' do
      it 'returns the correct default error' do
        expect(subject).to be_a(internal_server_error)
      end
    end
    # ... repeat ad nauseum for options in a case statement
  end
end
