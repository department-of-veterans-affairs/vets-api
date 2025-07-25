# frozen_string_literal: true

require 'rails_helper'
require 'ssoe/service'

# rubocop:disable RSpec/SpecFilePathFormat

RSpec.describe SSOe::Service, type: :service do
  let(:service) { described_class.new }

  describe '#get_traits' do
    let(:valid_params) do
      {
        credential_method: 'idme',
        credential_id: '12345',
        first_name: 'John',
        last_name: 'Doe',
        birth_date: '1980-01-01',
        ssn: '123-45-6789',
        email: 'john.doe@example.com',
        phone: '555-555-5555',
        street1: '123 Elm St',
        city: 'Springfield',
        state: 'IL',
        zipcode: '62701'
      }
    end

    context 'when the response is successful' do
      let(:raw_response) { double('raw_response', body: '<xml><icn>123456789</icn></xml>') }

      before do
        allow(service).to receive(:perform).and_return(raw_response)
      end

      it 'returns the raw response body' do
        response = service.get_traits(**valid_params)
        expect(response).to eq('<xml><icn>123456789</icn></xml>')
      end
    end

    context 'when there is a connection error' do
      before do
        allow(service).to receive(:perform).and_raise(Faraday::ConnectionFailed, 'Connection error')
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Connection error/)
        response = service.get_traits(**valid_params)
        expect(response).to be_nil
      end
    end

    context 'when there is a timeout error' do
      before do
        allow(service).to receive(:perform).and_raise(Faraday::TimeoutError, 'Timeout error')
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Timeout error/)
        response = service.get_traits(**valid_params)
        expect(response).to be_nil
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(service).to receive(:perform).and_raise(StandardError, 'Unexpected error')
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with(/Unexpected error/)
        response = service.get_traits(**valid_params)
        expect(response).to be_nil
      end
    end
  end
end

# rubocop:enable RSpec/SpecFilePathFormat
