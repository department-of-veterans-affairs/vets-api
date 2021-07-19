# frozen_string_literal: true

require 'rails_helper'

Faraday::Middleware.register_middleware(check_in_logging: Middleware::CheckInLogging)
Faraday::Response.register_middleware(check_in_errors: Middleware::Errors)

describe Middleware::Errors do
  describe '#on_complete' do
    let(:env) { OpenStruct.new('success?' => false, status: 'status', body: {}) }
    let(:env_400) do
      OpenStruct.new('success?' => false, status: 400, body: { 'errors' => ['errorMessage' => 'none'] }.to_json)
    end
    let(:env_403) { OpenStruct.new('success?' => false, status: 403, body: {}) }
    let(:env_404) { OpenStruct.new('success?' => false, status: 404, body: {}) }
    let(:env_409) { OpenStruct.new('success?' => false, status: 409, body: { 'message' => 'none' }.to_json) }
    let(:env_500) { OpenStruct.new('success?' => false, status: 500, body: {}) }

    let(:expected_exception) { Common::Exceptions::BackendServiceException }

    it 'handles errors' do
      expect { described_class.new.on_complete(env) }.to raise_error(expected_exception, /VA900/)
    end

    it 'handles 400 errors' do
      expect { described_class.new.on_complete(env_400) }.to raise_error(expected_exception, /CHECK_IN_400/)
    end

    it 'handles 409 errors' do
      expect { described_class.new.on_complete(env_409) }.to raise_error(expected_exception, /CHECK_IN_400/)
    end

    it 'handles 403 errors' do
      expect { described_class.new.on_complete(env_403) }.to raise_error(expected_exception, /CHECK_IN_403/)
    end

    it 'handles 404 errors' do
      expect { described_class.new.on_complete(env_404) }.to raise_error(expected_exception, /CHECK_IN_404/)
    end

    it 'handles 500 errors' do
      expect { described_class.new.on_complete(env_500) }.to raise_error(expected_exception, /CHECK_IN_502/)
    end
  end

  describe '#parse_error' do
    context 'with errors' do
      let(:body) { { 'errors': [{ 'errorMessage': 'error message' }] }.to_json }

      it 'returns the error message' do
        expect(described_class.new.parse_error(body)).to eq('error message')
      end
    end

    context 'without errors' do
      let(:body) { { 'message': 'a message' }.to_json }

      it 'returns the error message' do
        expect(described_class.new.parse_error(body)).to eq('a message')
      end
    end

    context 'rescued output' do
      let(:body) { 'foo' }

      it 'returns the error message' do
        expect(described_class.new.parse_error(body)).to eq('foo')
      end
    end
  end
end
