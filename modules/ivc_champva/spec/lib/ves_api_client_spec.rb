# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe IvcChampva::VesApi::Client do
  let(:client) { described_class.new }
  let(:transaction_uuid) { '12345' }
  let(:acting_user) { 'test_user' }
  let(:ves_request_data) { instance_double(IvcChampva::VesRequest, to_json: '{}') }

  describe '#submit_1010d' do
    before do
      allow(client).to receive(:connection).and_return(double(post: response))
    end

    context 'successful response from VES' do
      let(:response) { instance_double(Faraday::Response, status: 200, body: '{}') }

      it 'does not raise an error' do
        expect do
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        end.not_to raise_error
      end

      it 'calls monitor.track_request' do
        expect(client.monitor).to receive(:track_request).with(
          'info',
          "IVC ChampVa Forms - Successful submission to VES for form #{transaction_uuid}",
          'api.ivc_champva_form.ves_response.success',
          call_location: anything,
          form_uuid: transaction_uuid,
          messages: '{}',
          status: 200
        )

        client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
      end

      it 'does not return nil on success' do
        expect(client.submit_1010d(transaction_uuid, acting_user, ves_request_data).nil?).to be(false)
      end
    end

    context '400 response from VES' do
      let(:response) { instance_double(Faraday::Response, status: 400, body: '{}') }

      it 'raises a VesApiError' do
        expect do
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        end.to raise_error(IvcChampva::VesApi::VesApiError)
      end

      it 'calls monitor.track_request' do
        expect(client.monitor).to receive(:track_request).with(
          'error',
          "IVC ChampVa Forms - Error on submission to VES for form #{transaction_uuid}",
          'api.ivc_champva_form.ves_response.failure',
          call_location: anything,
          form_uuid: transaction_uuid,
          messages: '{}',
          status: 400
        )

        expect do
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        end.to raise_error(IvcChampva::VesApi::VesApiError)
      end
    end

    context 'not authorized response from VES' do
      let(:response) { instance_double(Faraday::Response, status: 403, body: '{}') }

      it 'raises a VesApiError' do
        expect do
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        end.to raise_error(IvcChampva::VesApi::VesApiError)
      end
    end

    context '500 response from VES' do
      let(:response) { instance_double(Faraday::Response, status: 500, body: '{}') }

      it 'raises a VesApiError' do
        expect do
          client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
        end.to raise_error(IvcChampva::VesApi::VesApiError)
      end
    end
  end

  describe 'check options' do
    it 'sets the request timeout to at least 5 seconds' do
      connection = instance_double(Common::Client::Base::Connection) # Mock the private connection class
      response = instance_double(Faraday::Response, status: 200, body: '')
      allow(client).to receive(:connection).and_return(connection)

      expect(connection).to receive(:post) do |&block|
        request = double(options: Faraday::RequestOptions.new)
        allow(request).to receive(:headers=)
        allow(request).to receive(:body=)
        allow(request).to receive(:options=) do |options|
          expect(options[:timeout]).to be > 5
        end
        block.call(request)
        response
      end

      client.submit_1010d(transaction_uuid, acting_user, ves_request_data)
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
