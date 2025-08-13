# frozen_string_literal: true

require 'rails_helper'
require 'ssoe/service'
require 'ssoe/get_ssoe_traits_by_cspid_message'
require 'ssoe/models/user'
require 'ssoe/models/address'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe SSOe::Service, type: :service do
  subject(:service) { described_class.new }

  describe '#get_traits' do
    let(:user) do
      SSOe::Models::User.new(
        first_name: 'John',
        last_name: 'Doe',
        birth_date: '1980-01-01',
        ssn: '123-45-6789',
        email: 'john.doe@example.com',
        phone: '555-555-5555'
      )
    end

    let(:address) do
      SSOe::Models::Address.new(
        street1: '123 Elm St',
        city: 'Springfield',
        state: 'IL',
        zipcode: '62701'
      )
    end

    let(:credential_method) { 'idme' }
    let(:credential_id) { '12345' }

    shared_examples 'responds with 502' do
      it 'logs the error and returns the error response' do
        error_message = '[SSOe::Service::get_traits] connection error: Common::Client::Errors::ClientError - ' \
                        'Failed to open TCP connection to int.services.eauth.va.gov:9303 ' \
                        '(getaddrinfo: nodename nor servname provided, or not known)'

        expect(Rails.logger).to receive(:error).with(error_message)

        response = service.get_traits(
          credential_method:,
          credential_id:,
          user:,
          address:
        )

        expect(response).to eq({
                                 success: false,
                                 error: {
                                   code: 502,
                                   message: 'Failed to open TCP connection to int.services.eauth.va.gov:9303 ' \
                                            '(getaddrinfo: nodename nor servname provided, or not known)'
                                 }
                               })
      end
    end

    context 'when the response is successful' do
      context 'parse_response' do
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

        it 'handles unknown response format' do
          body = '<unexpected>response</unexpected>'

          expect { service.send(:parse_response, body) }.to raise_error(StandardError, 'Unable to parse SOAP response')
        end
      end
    end

    context 'when the response contains a valid ICN' do
      it 'parses the ICN from the response' do
        response = service.send(:parse_response, <<~XML)
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <getSSOeTraitsByCSPIDResponse>
                <icn>123498767V234859</icn>
              </getSSOeTraitsByCSPIDResponse>
            </soap:Body>
          </soap:Envelope>
        XML

        expect(response).to eq({ success: true, icn: '123498767V234859' })
      end
    end

    context 'when the response contains a fault' do
      it 'parses the fault from the response' do
        response = service.send(:parse_response, <<~XML)
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <soap:Fault>
                <faultcode>soap:Client</faultcode>
                <faultstring>Invalid CSPID</faultstring>
              </soap:Fault>
            </soap:Body>
          </soap:Envelope>
        XML

        expect(response).to eq({
                                 success: false,
                                 error: {
                                   code: 'soap:Client',
                                   message: 'Invalid CSPID'
                                 }
                               })
      end
    end

    context 'when the response is unexpected' do
      it 'raises an error' do
        body = '<unexpected>response</unexpected>'
        expect { service.send(:parse_response, body) }.to raise_error(StandardError, 'Unable to parse SOAP response')
      end
    end

    context 'when there is a connection error' do
      before do
        VCR.configure { |c| c.allow_http_connections_when_no_cassette = true }
        allow(Faraday).to receive(:post).and_raise(Faraday::ConnectionFailed, 'Connection error')
      end

      after do
        VCR.configure { |c| c.allow_http_connections_when_no_cassette = false }
      end

      it_behaves_like 'responds with 502'
    end

    context 'when there is a timeout error' do
      before do
        VCR.configure { |c| c.allow_http_connections_when_no_cassette = true }
        allow(Faraday).to receive(:post).and_raise(Faraday::TimeoutError, 'Timeout error')
      end

      after do
        VCR.configure { |c| c.allow_http_connections_when_no_cassette = false }
      end

      it_behaves_like 'responds with 502'
    end

    context 'when an unexpected error occurs', vcr: false do
      before do
        allow_any_instance_of(Common::Client::Base).to receive(:perform).and_raise(StandardError, 'Unexpected error')
      end

      it 'logs the error and returns an unknown error response' do
        expect(Rails.logger).to receive(:error).with(
          '[SSOe::Service::get_traits] unknown error: StandardError - Unexpected error'
        )

        response = service.get_traits(
          credential_method:,
          credential_id:,
          user:,
          address:
        )

        expect(response).to eq({
                                 success: false,
                                 error: {
                                   code: 500,
                                   message: 'Unexpected error'
                                 }
                               })
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
