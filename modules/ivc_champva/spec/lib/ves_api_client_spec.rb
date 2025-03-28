# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe IvcChampva::VesApi::Client do
  let(:client) { described_class.new }
  let(:transaction_uuid) { '12345' }
  let(:acting_user) { 'test_user' }
  let(:ves_request_data) { instance_double('IvcChampva::VesRequest', to_json: '{}') }

  describe '#submit_1010d' do
    before do
      allow(client).to receive(:connection).and_return(double(post: response))
    end

    context 'successful response from VES' do
      let(:response) { instance_double('Faraday::Response', status: 200, body: '{}') }

      it 'does not raise an error' do
        expect {
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        }.not_to raise_error
      end
    end

    context '400 response from VES' do
      let(:response) { instance_double('Faraday::Response', status: 400, body: '{}') }

      it 'raises a VesApiError' do
        expect {
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        }.to raise_error(IvcChampva::VesApi::VesApiError)
      end
    end

    context 'not authorized response from VES' do
      let(:response) { instance_double('Faraday::Response', status: 403, body: '{}') }

      it 'raises a VesApiError' do
        expect {
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        }.to raise_error(IvcChampva::VesApi::VesApiError)
      end
    end

    context '500 response from VES' do
      let(:response) { instance_double('Faraday::Response', status: 500, body: '{}') }

      it 'raises a VesApiError' do
        expect {
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        }.to raise_error(IvcChampva::VesApi::VesApiError)
      end
    end
  end

  describe 'headers' do
    it 'returns the right headers' do
      result = client.headers('the_right_uuid', 'the_right_acting_user')

      expect(result[:content_type]).to eq('application/json')
      expect(result['apiKey']).to eq('fake_api_key')
      expect(result['transactionUUId']).to eq('the_right_uuid')
      expect(result['acting-user']).to eq('the_right_acting_user')
    end

    it 'returns the right headers with nil acting user' do
      result = client.headers('the_right_uuid', nil)

      expect(result[:content_type]).to eq('application/json')
      expect(result['apiKey']).to eq('fake_api_key')
      expect(result['transactionUUId']).to eq('the_right_uuid')
      expect(result['acting-user']).to eq('')
    end
  end

  # Temporary, delete me
  # This test is used to hit the production endpoint when running locally.
  # It can be removed once we have some real code that uses the VES API client.
  describe 'hit the production endpoint', skip: 'this is useful as a way to hit the API during local development' do
    let(:forced_headers) do
      {
        :content_type => 'application/json',
        # use the following line when running locally tp pull the key from an environment variable
        'x-api-key' => ENV.fetch('VES_API_KEY'), # to set: export VES_API_KEY=insert1the2api3key4here
        'transactionUUId' => '1234',
        'acting-user' => ''
      }
    end

    before do
      allow_any_instance_of(IvcChampva::VesApi::Client).to receive(:headers).with(anything, anything)
                                                                            .and_return(forced_headers)
    end
  end
end
