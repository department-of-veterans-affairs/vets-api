# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/error'

RSpec.describe VANotify::Error do
  describe '#initialize' do
    let(:status_code) { 400 }
    let(:body) { 'Bad Request' }
    let(:context) { { template_id: '1234' } }

    it 'sets status_code, body, and context' do
      error = described_class.new(status_code, body, context)

      expect(error.status_code).to eq(400)
      expect(error.body).to eq('Bad Request')
      expect(error.context).to eq({ template_id: '1234' })
    end

    context 'when body is a hash with errors' do
      let(:body) { { 'errors' => [{ 'error' => 'ValidationError', 'message' => 'Missing field' }] } }

      it 'builds message from parsed errors' do
        error = described_class.new(status_code, body, context)
        expect(error.message).to eq('ValidationError: Missing field | template_id: 1234')
      end
    end

    context 'when body is a hash with message' do
      let(:body) { { 'message' => 'Something went wrong' } }

      it 'builds message from body message' do
        error = described_class.new(status_code, body, context)
        expect(error.message).to eq('Something went wrong | template_id: 1234')
      end
    end

    context 'when context is empty' do
      let(:context) { {} }

      it 'builds message without context portion' do
        error = described_class.new(status_code, body, context)
        expect(error.message).to eq('Bad Request')
      end
    end
  end

  describe '#log_error' do
    let(:body) { 'Bad Request' }
    let(:context) { { template_id: '1234' } }
    let(:expected_log_args) do
      {
        status_code: 400,
        body:,
        context:,
        message: 'Bad Request | template_id: 1234'
      }
    end

    it 'logs with the base class name' do
      error = described_class.new(400, body, context)
      expect(Rails.logger).to receive(:error).with('VANotify::Error', expected_log_args)
      error.log_error
    end

    it 'logs with the typed subclass name' do
      error = VANotify::BadRequest.new(400, body, context)
      expect(Rails.logger).to receive(:error).with('VANotify::BadRequest', expected_log_args)
      error.log_error
    end
  end

  describe '.from_generic_error' do
    let(:body) { 'Error occurred' }
    let(:context) { { template_id: '5678' } }

    {
      400 => VANotify::BadRequest,
      401 => VANotify::Unauthorized,
      403 => VANotify::Forbidden,
      404 => VANotify::NotFound,
      429 => VANotify::RateLimitExceeded,
      500 => VANotify::ServerError,
      502 => VANotify::Error
    }.each do |status, expected_class|
      it "returns #{expected_class} for status #{status}" do
        generic_error = instance_double(Common::Client::Errors::ClientError, status:, body:)
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(expected_class)
        expect(error.status_code).to eq(status)
        expect(error.context).to eq(context)
      end
    end
  end
end
