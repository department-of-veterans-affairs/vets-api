# frozen_string_literal: true

require 'rails_helper'
require 'ssoe/service'
require 'ssoe/get_ssoe_traits_by_cspid_message'
require 'ssoe/models/user'
require 'ssoe/models/address'
require 'ssoe/errors'

# rubocop:disable RSpec/SpecFilePathFormat, Style/MultilineBlockChain
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

    context 'when the response is successful' do
      it 'returns the parsed ICN response' do
        VCR.use_cassette('mpi/get_traits/success') do
          expected_response = {
            success: true,
            icn: '123498767V234859'
          }

          response = service.get_traits(
            credential_method:,
            credential_id:,
            user:,
            address:
          )

          expect(response).to eq(expected_response)
        end
      end
    end

    context 'when the response has a SOAP fault (client error)' do
      it 'raises RequestError and logs the error' do
        VCR.use_cassette('mpi/get_traits/error') do
          expect(Rails.logger).to receive(:error).with(
            a_string_starting_with('[SSOe::Service::get_traits] client error:')
          )

          expect do
            service.get_traits(
              credential_method:,
              credential_id:,
              user:,
              address:
            )
          end.to raise_error(SSOe::Errors::RequestError) do |error|
            expect(error.message).to include('[SSOe][Service] Client error')
          end
        end
      end
    end

    context 'when parse_response receives a SOAP fault' do
      it 'raises SOAPFaultError with fault information' do
        fault_xml = Ox.parse(<<~XML)
          <Envelope>
            <Body>
              <Fault>
                <faultcode>env:Server</faultcode>
                <faultstring>Internal Server Error</faultstring>
              </Fault>
            </Body>
          </Envelope>
        XML

        expect do
          service.send(:parse_response, fault_xml)
        end.to raise_error(SSOe::Errors::SOAPFaultError) do |error|
          expect(error.message).to include('Internal Server Error')
          expect(error.message).to include('env:Server')
        end
      end
    end

    context 'when the response is unexpected' do
      it 'raises SOAPParseError' do
        body = '<unexpected>response</unexpected>'

        expect do
          service.send(:parse_response, body)
        end.to raise_error(SSOe::Errors::SOAPParseError, '[SSOe][Service] Unable to parse SOAP response')
      end
    end

    context 'when there is a connection error' do
      before do
        allow_any_instance_of(SSOe::Service).to receive(:perform)
          .and_raise(Faraday::ConnectionFailed.new('Connection error'))
      end

      it 'logs the error and raises ConnectionError' do
        expect(Rails.logger).to receive(:error).with(
          a_string_starting_with('[SSOe::Service::get_traits] connection error:')
        )

        expect do
          service.get_traits(
            credential_method:,
            credential_id:,
            user:,
            address:
          )
        end.to raise_error(SSOe::Errors::ConnectionError) do |error|
          expect(error.message).to include('[SSOe][Service] Connection error')
        end
      end
    end

    context 'when there is a timeout error' do
      before do
        allow_any_instance_of(SSOe::Service).to receive(:perform)
          .and_raise(Faraday::TimeoutError.new('Timeout error'))
      end

      it 'logs the error and raises TimeoutError' do
        expect(Rails.logger).to receive(:error).with(
          a_string_starting_with('[SSOe::Service::get_traits] timeout error:')
        )

        expect do
          service.get_traits(
            credential_method:,
            credential_id:,
            user:,
            address:
          )
        end.to raise_error(SSOe::Errors::TimeoutError) do |error|
          expect(error.message).to include('[SSOe][Service] Timeout error')
        end
      end
    end

    context 'when an unexpected error occurs', vcr: false do
      before do
        allow_any_instance_of(Common::Client::Base).to receive(:perform)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'logs the error and raises UnknownError' do
        expect(Rails.logger).to receive(:error).with(
          '[SSOe::Service::get_traits] unknown error: StandardError - Unexpected error'
        )

        expect do
          service.get_traits(
            credential_method:,
            credential_id:,
            user:,
            address:
          )
        end.to raise_error(SSOe::Errors::UnknownError) do |error|
          expect(error.message).to include('[SSOe][Service] Unknown error')
        end
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat, Style/MultilineBlockChain
