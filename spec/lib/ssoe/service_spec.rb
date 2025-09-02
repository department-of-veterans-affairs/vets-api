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
        expect(Rails.logger).to receive(:error).with(
          a_string_starting_with(
            '[SSOe::Service::get_traits] connection error:'
          )
        )

        response = service.get_traits(
          credential_method:,
          credential_id:,
          user:,
          address:
        )

        expect(response[:success]).to be false
        expect(response[:error][:code]).to eq(502)
        expect(response[:error][:message]).to be_a(String)
      end
    end

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
      it 'returns the error response and logs the error' do
        VCR.use_cassette('mpi/get_traits/error') do
          expected_response = {
            success: false,
            error: {
              code: 400,
              message: 'SOAP HTTP call failed'
            }
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

    context 'when the response is unexpected' do
      it 'raises an error' do
        body = '<unexpected>response</unexpected>'
        expect { service.send(:parse_response, body) }.to raise_error(StandardError, 'Unable to parse SOAP response')
      end
    end

    context 'when there is a connection error' do
      before do
        allow_any_instance_of(SSOe::Service).to receive(:perform).and_raise(Faraday::ConnectionFailed.new(
                                                                              'Connection error'
                                                                            ))
      end

      it_behaves_like 'responds with 502'
    end

    context 'when there is a timeout error' do
      before do
        allow_any_instance_of(SSOe::Service).to receive(:perform).and_raise(Faraday::TimeoutError.new(
                                                                              'Timeout error'
                                                                            ))
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
