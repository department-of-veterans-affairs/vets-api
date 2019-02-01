# frozen_string_literal: true

require 'rails_helper'
require 'support/mvi/stub_mvi'

RSpec.describe Users::ExceptionHandler do
  let(:user) { build(:user, :loa3) }
  let(:message) { 'the server responded with status 503' }
  let(:error_body) { { 'status' => 'some service unavailable status' } }
  let(:service) { 'Vet360' }

  describe '.initialize' do
    context 'when initialized without a nil error' do
      it 'raises an exception' do
        expect { Users::ExceptionHandler.new(nil, service) }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end
  end

  describe '#serialize_error' do
    context 'with a Common::Client::Errors::ClientError' do
      let(:error) { Common::Client::Errors::ClientError.new(message, 503, error_body) }
      let(:results) { Users::ExceptionHandler.new(error, service).serialize_error }

      it 'returns a serialized version of the error' do
        expect(results[:description]).to include message, error_body.to_s
      end

      it 'identifies the external service' do
        expect(results[:external_service]).to eq service
      end

      it 'sets the start_time' do
        expect(results[:start_time]).to be_present
      end

      it 'returns a status' do
        expect(results[:status]).to eq 503
      end
    end

    context 'with a Common::Exceptions::GatewayTimeout' do
      let(:error) { Common::Exceptions::GatewayTimeout.new }
      let(:results) { Users::ExceptionHandler.new(error, service).serialize_error }

      it 'returns a serialized version of the error' do
        expect(results[:description]).to include 'Gateway timeout', '504'
      end

      it 'returns a status' do
        expect(results[:status]).to eq 504
      end
    end

    context 'with a Common::Exceptions::BackendServiceException' do
      let(:error) { server_error_exception }
      let(:results) { Users::ExceptionHandler.new(error, service).serialize_error }

      it 'returns a serialized version of the error' do
        expect(results[:description]).to include 'MVI_503', '503', 'Service unavailable'
      end

      it 'returns a status' do
        expect(results[:status]).to eq 503
      end
    end

    context 'with a EMISRedis::VeteranStatus::NotAuthorized' do
      let(:error) { EMISRedis::VeteranStatus::NotAuthorized.new(status: 401) }
      let(:results) { Users::ExceptionHandler.new(error, service).serialize_error }

      it 'returns a serialized version of the error' do
        expect(results[:description]).to include 'NOT_AUTHORIZED', 'EMISRedis::VeteranStatus::NotAuthorized'
      end

      it 'returns a status' do
        expect(results[:status]).to eq 401
      end
    end

    context 'with a EMISRedis::VeteranStatus::RecordNotFound' do
      let(:error) { EMISRedis::VeteranStatus::RecordNotFound.new(status: 404) }
      let(:results) { Users::ExceptionHandler.new(error, service).serialize_error }

      it 'returns a serialized version of the error' do
        expect(results[:description]).to include 'NOT_FOUND', 'EMISRedis::VeteranStatus::RecordNotFound'
      end

      it 'returns a status' do
        expect(results[:status]).to eq 404
      end
    end

    context 'with a StandardError' do
      let(:error) { StandardError.new(message) }
      let(:results) { Users::ExceptionHandler.new(error, service).serialize_error }

      it 'returns a serialized version of the error' do
        expect(results[:description]).to include message, 'StandardError'
      end

      it 'returns a status' do
        expect(results[:status]).to eq 503
      end
    end
  end
end
