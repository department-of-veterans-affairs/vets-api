# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Errors::ErrorHandler do
  let(:gateway_timeout_error) { StandardError.new }
  let(:internal_server_error) { Common::Exceptions::InternalServerError }
  let(:pundit_not_auth_error) { Pundit::NotAuthorizedError }
  let(:parameter_missing_error) { ActionController::ParameterMissing }
  let(:unknown_format_error) { ActionController::UnknownFormat }
  let(:not_safe_host_error) { Common::Exceptions::NotASafeHostError }
  let(:base_error) { Common::Exceptions::BaseError }
  let(:breakers_outage_error) { Breakers::OutageException }
  let(:client_error) { Common::Client::Errors::ClientError }

  describe '#log_error' do
    subject { described_class.new(client_error.new) }
    
    it 'calls instance log error method' do
      allow_any_instance_of(described_class).to receive(:log_error).and_return(true)
      expect(subject.log_error).to be(true)
    end
    
    #TODO not sure if testing super is even possible behavior to test?
    it 'calls the super log error' do
      allow_any_instance_of(SentryLogging).to receive(:log_error).and_return(true)
    end

    context 'when ancestor does not implement `#log_error`' do
      xit 'raises a NotImplementedError' do
        expect(subject.log_error).to raise_error(NotImplementedError)
        pending 'this logic is not yet implemented'
      end
    end
  end

  describe '#transformed_error' do
  
    context 'when given an error without a specific counterpart' do
      subject { described_class.new(StandardError.new).transformed_error }
      it 'returns the correct default error' do
        expect(subject).to be_a(internal_server_error)
      end
    end

    context 'when given an error is an pundit not auth error' do
      subject { described_class.new(pundit_not_auth_error.new).transformed_error }
      it 'returns the correct default error' do
        expect(subject).to be_a(Common::Exceptions::Forbidden)
      end
    end
    
    context 'when given an error is a parameter missing error' do
      subject { described_class.new(parameter_missing_error.new("missing_param")).transformed_error }
      it 'returns the correct parameter missing error' do
        expect(subject).to be_a(Common::Exceptions::ParameterMissing)
      end
    end
    
    context 'when given an error is an unknown format error' do
      subject { described_class.new(unknown_format_error.new).transformed_error }
      it 'returns the correct unknown format error' do
        expect(subject).to be_a(Common::Exceptions::UnknownFormat)
      end
    end
    
    context 'when given an error is a base error' do
      subject { described_class.new(not_safe_host_error.new("1234")).transformed_error }
      it 'returns the correct error inheriting from base error' do
        expect(subject).to be_a(not_safe_host_error)
      end
    end
    
    #TODO cannot figure out what the first param - outage is supposed to be? 
    context 'when given an error is a breakers outage error' do
      subject { described_class.new(breakers_outage_error.new(nil, Search::Service)).transformed_error }
      xit 'returns the correct service outage error' do
        expect(subject).to be_a(Common::Exceptions::ServiceOutage)
      end
    end
    
    context 'when given an error is a client error' do
      subject { described_class.new(client_error.new).transformed_error }
      it 'returns the correct service outage error' do
        expect(subject).to be_a(Common::Exceptions::ServiceOutage)
      end
    end

  end
end
