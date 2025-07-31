# frozen_string_literal: true

require 'rails_helper'
require 'ssoe/service'
require 'ssoe/get_ssoe_traits_by_cspid_message'

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

    shared_examples 'a parsed response' do |xml:, expected:|
      let(:raw_response) { double('raw_response', body: xml) }

      before { allow(service).to receive(:perform).and_return(raw_response) }

      it 'parses and returns the expected result' do
        response = service.get_traits(**valid_params)
        expect(response).to eq(expected)
      end
    end

    context 'when the response contains a valid ICN' do
      it_behaves_like 'a parsed response',
                      xml: <<~XML,
                        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
                          <soap:Body>
                            <getSSOeTraitsByCSPIDResponse>
                              <icn>123498767V234859</icn>
                            </getSSOeTraitsByCSPIDResponse>
                          </soap:Body>
                        </soap:Envelope>
                      XML
                      expected: { success: true, icn: '123498767V234859' }
    end

    context 'when the response contains a fault' do
      it_behaves_like 'a parsed response',
                      xml: <<~XML,
                        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
                          <soap:Body>
                            <soap:Fault>
                              <faultcode>soap:Client</faultcode>
                              <faultstring>Invalid CSPID</faultstring>
                            </soap:Fault>
                          </soap:Body>
                        </soap:Envelope>
                      XML
                      expected: {
                        success: false,
                        error: {
                          code: 'soap:Client',
                          message: 'Invalid CSPID'
                        }
                      }
    end

    context 'when the response is unexpected' do
      it_behaves_like 'a parsed response',
                      xml: '<unexpected>response</unexpected>',
                      expected: {
                        success: false,
                        error: {
                          code: 'UnknownError',
                          message: 'Unable to parse SOAP response'
                        }
                      }
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

  describe '#parse_response' do
    it 'parses ICN response' do
      body = <<~XML
        <Envelope>
          <Body>
            <getSSOeTraitsByCSPIDResponse>
              <icn>123498767V234859</icn>
            </getSSOeTraitsByCSPIDResponse>
          </Body>
        </Envelope>
      XML

      result = service.send(:parse_response, body)
      expect(result).to eq({ success: true, icn: '123498767V234859' })
    end

    it 'parses fault response' do
      body = <<~XML
        <Envelope>
          <Body>
            <Fault>
              <faultcode>soap:Client</faultcode>
              <faultstring>Error</faultstring>
            </Fault>
          </Body>
        </Envelope>
      XML

      result = service.send(:parse_response, body)
      expect(result).to eq({ success: false, error: { code: 'soap:Client', message: 'Error' } })
    end
  end
end

# rubocop:enable RSpec/SpecFilePathFormat
