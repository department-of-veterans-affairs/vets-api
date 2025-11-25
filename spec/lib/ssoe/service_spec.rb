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
    subject(:get_traits) { service.get_traits(credential_method:, credential_id:, user:, address:) }

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

    shared_examples 'raises a ServerError' do
      it 'raises a SSOe::Errors::ServerError' do
        expect { get_traits }.to raise_error(SSOe::Errors::ServerError)
      end
    end

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

    context 'when the response has a SOAP fault (client error)' do
      it 'raises a ParsingError' do
        fault_body_xml = <<~XML
          <Envelope>
            <Body>
              <Fault>
                <faultcode>Server.SOAPFault</faultcode>
                <faultstring>Some SOAP fault</faultstring>
              </Fault>
            </Body>
          </Envelope>
        XML
        fault_body = Ox.parse(fault_body_xml)
        raw_response = double(body: fault_body)
        allow_any_instance_of(SSOe::Service).to receive(:perform).and_return(raw_response)

        expect do
          get_traits
        end.to raise_error(SSOe::Errors::ParsingError, 'SOAP Fault: Server.SOAPFault - Some SOAP fault')
      end
    end

    context 'when the response is unparseable' do
      it 'raises a ParsingError' do
        unexpected_body_xml = '<unexpected>response</unexpected>'
        raw_response = double(body: Ox.parse(unexpected_body_xml))
        allow_any_instance_of(SSOe::Service).to receive(:perform).and_return(raw_response)

        expect { get_traits }.to raise_error(SSOe::Errors::ParsingError, 'Unable to parse SOAP response')
      end
    end

    context 'when there is a connection error' do
      before do
        allow_any_instance_of(SSOe::Service).to receive(:perform)
          .and_raise(Faraday::ConnectionFailed.new('Connection error'))
      end

      it_behaves_like 'raises a ServerError'
    end

    context 'when there is a timeout error' do
      before do
        allow_any_instance_of(SSOe::Service).to receive(:perform).and_raise(Faraday::TimeoutError.new('Timeout error'))
      end

      it_behaves_like 'raises a ServerError'
    end

    context 'when an unexpected error occurs', vcr: false do
      before do
        allow_any_instance_of(Common::Client::Base).to receive(:perform).and_raise(StandardError, 'Unexpected error')
      end

      it 'raises a SSOe::Errors::Error' do
        expect { get_traits }.to raise_error(SSOe::Errors::Error, /StandardError - Unexpected error/)
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
