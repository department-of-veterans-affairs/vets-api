# frozen_string_literal: true

require 'rails_helper'
require 'ssoe/service'
require 'ssoe/get_ssoe_traits_by_cspid_message'
require 'ssoe/models/user'
require 'ssoe/models/address'
require 'ssoe/errors'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe SSOe::Service, type: :service do
  describe '#get_traits' do
    subject(:get_traits) do
      described_class.new.get_traits(
        credential_method:,
        credential_id:,
        user:,
        address:
      )
    end

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

          expect(get_traits).to eq(expected_response)
        end
      end
    end

    context 'when the response has a client error' do
      let(:error_message) { '[SSOe][Service] Common::Client::Errors::HTTPError - SOAP HTTP call failed' }

      it 'raises RequestError' do
        VCR.use_cassette('mpi/get_traits/error') do
          expect { get_traits }.to raise_error(SSOe::Errors::RequestError).with_message(error_message)
        end
      end
    end

    context 'when the response contains a SOAP fault' do
      let(:error_message) { '[SSOe][Service] SOAP Fault - Internal Server Error (Code: env:Server)' }

      it 'raises ParsingError', vcr: false do
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

        fault_response = double(body: fault_xml)
        allow_any_instance_of(described_class).to receive(:perform).and_return(fault_response)

        expect { get_traits }.to raise_error(SSOe::Errors::ParsingError).with_message(error_message)
      end
    end

    context 'when the response is unparseable' do
      let(:error_message) { '[SSOe][Service] Unable to parse SOAP response' }

      it 'raises ParsingError', vcr: false do
        bad_response = double(body: '<unexpected>response</unexpected>')
        allow_any_instance_of(described_class).to receive(:perform).and_return(bad_response)

        expect { get_traits }.to raise_error(SSOe::Errors::ParsingError).with_message(error_message)
      end
    end

    context 'when there is a connection error' do
      let(:error_message) { '[SSOe][Service] Faraday::ConnectionFailed - Connection error' }

      before do
        allow_any_instance_of(described_class).to receive(:perform)
          .and_raise(Faraday::ConnectionFailed.new('Connection error'))
      end

      it 'raises ServerError' do
        expect { get_traits }.to raise_error(SSOe::Errors::ServerError).with_message(error_message)
      end
    end

    context 'when there is a timeout error' do
      let(:error_message) { '[SSOe][Service] Faraday::TimeoutError - Timeout error' }

      before do
        allow_any_instance_of(described_class).to receive(:perform)
          .and_raise(Faraday::TimeoutError.new('Timeout error'))
      end

      it 'raises ServerError' do
        expect { get_traits }.to raise_error(SSOe::Errors::ServerError).with_message(error_message)
      end
    end

    context 'when there is a gateway timeout' do
      let(:error_message) { '[SSOe][Service] Common::Exceptions::GatewayTimeout - Gateway timeout' }

      before do
        allow_any_instance_of(described_class).to receive(:perform)
          .and_raise(Common::Exceptions::GatewayTimeout.new('Gateway timeout'))
      end

      it 'raises ServerError' do
        expect { get_traits }.to raise_error(SSOe::Errors::ServerError).with_message(error_message)
      end
    end

    context 'when an unexpected error occurs', vcr: false do
      let(:error_message) { '[SSOe][Service] StandardError - Unexpected error' }

      before do
        allow_any_instance_of(Common::Client::Base).to receive(:perform)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'raises generic Error' do
        expect { get_traits }.to raise_error(SSOe::Errors::Error).with_message(error_message)
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
