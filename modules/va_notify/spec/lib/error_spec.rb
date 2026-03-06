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

    it 'does not log on initialization' do
      expect(Rails.logger).not_to receive(:error)
      described_class.new(status_code, body, context)
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
    it 'logs with the class name, status, body, context, and message' do
      error = described_class.new(400, 'Bad Request', { template_id: '1234' })

      expect(Rails.logger).to receive(:error).with(
        'VANotify::Error',
        status_code: 400,
        body: 'Bad Request',
        context: { template_id: '1234' },
        message: 'Bad Request | template_id: 1234'
      )

      error.log_error
    end

    it 'logs the typed subclass name' do
      error = VANotify::BadRequest.new(400, 'Bad Request', { template_id: '1234' })

      expect(Rails.logger).to receive(:error).with(
        'VANotify::BadRequest',
        status_code: 400,
        body: 'Bad Request',
        context: { template_id: '1234' },
        message: 'Bad Request | template_id: 1234'
      )

      error.log_error
    end
  end

  describe '.from_generic_error' do
    let(:generic_error) { instance_double(Common::Client::Errors::ClientError, status: status_code, body:) }
    let(:body) { 'Error occurred' }
    let(:context) { { template_id: '5678' } }

    context 'when status is 400' do
      let(:status_code) { 400 }

      it 'returns a VANotify::BadRequest' do
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(VANotify::BadRequest)
      end
    end

    context 'when status is 401' do
      let(:status_code) { 401 }

      it 'returns a VANotify::Unauthorized' do
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(VANotify::Unauthorized)
      end
    end

    context 'when status is 403' do
      let(:status_code) { 403 }

      it 'returns a VANotify::Forbidden' do
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(VANotify::Forbidden)
      end
    end

    context 'when status is 404' do
      let(:status_code) { 404 }

      it 'returns a VANotify::NotFound' do
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(VANotify::NotFound)
      end
    end

    context 'when status is 429' do
      let(:status_code) { 429 }

      it 'returns a VANotify::RateLimitExceeded' do
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(VANotify::RateLimitExceeded)
      end
    end

    context 'when status is 500' do
      let(:status_code) { 500 }

      it 'returns a VANotify::ServerError' do
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(VANotify::ServerError)
      end
    end

    context 'when status is unrecognized' do
      let(:status_code) { 502 }

      it 'returns a VANotify::Error' do
        error = described_class.from_generic_error(generic_error, context)
        expect(error).to be_a(VANotify::Error)
      end
    end

    it 'logs with the typed class name when log_error is called' do
      generic_error = instance_double(Common::Client::Errors::ClientError, status: 400, body: 'Bad Request')

      error = described_class.from_generic_error(generic_error, context)

      expect(Rails.logger).to receive(:error).with(
        'VANotify::BadRequest',
        status_code: 400,
        body: 'Bad Request',
        context:,
        message: 'Bad Request | template_id: 5678'
      )

      error.log_error
    end
  end
end
