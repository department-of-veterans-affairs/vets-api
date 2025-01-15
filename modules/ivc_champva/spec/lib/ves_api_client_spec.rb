# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe IvcChampva::VesApi::Client do
  subject { described_class.new }

  describe 'submit_1010d' do
    let(:body200) do # ves api response with HTTP status 200
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'ves_api_json',
                                     'submit_1010d_response_200.json')
      fixture_path.read
    end

    let(:body400) do # ves api response with HTTP status 400
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'ves_api_json',
                                     'submit_1010d_response_400.json')
      fixture_path.read
    end

    let(:body403) do # ves api response with HTTP status 403 forbidden
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'ves_api_json',
                                     'submit_1010d_response_403.json')
      fixture_path.read
    end

    context 'successful response' do
      let(:faraday_response) { double('Faraday::Response', status: 200, body: body200) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'returns TODO' do
        result = subject.submit_1010d('uuid', 'acting_user')

        # TODO expect...
      end
    end

    context 'unsuccessful response with HTTP status 400' do
      let(:faraday_response) { double('Faraday::Response', status: 400, body: body400) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'raises error when response is 400' do
        expect { subject.submit_1010d('uuid', 'acting_user') }.to raise_error(IvcChampva::VesApi::VesApiError)

        # TODO error indicates details from the API's response about what the problem is
      end
    end

    context 'unsuccessful response with HTTP status 403' do
      let(:faraday_response) { double('Faraday::Response', status: 403, body: body403) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'raises error when response is 403' do
        expect { subject.submit_1010d('uuid', 'acting_user') }.to raise_error(IvcChampva::VesApi::VesApiError)

        # TODO error indicates forbidden / not authorized
      end
    end
  end if false # TODO remove this line when the method is implemented

  describe 'headers' do
    it 'returns the right headers' do
      result = subject.headers('the_right_uuid', 'the_right_acting_user')

      expect(result[:content_type]).to eq('application/json')
      expect(result['apiKey']).to eq('fake_api_key')
      expect(result['transactionUUId']).to eq('the_right_uuid')
      expect(result['acting-user']).to eq('the_right_acting_user')
    end

    it 'returns the right headers with nil acting user' do
      result = subject.headers('the_right_uuid', nil)

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

    it 'returns a good response' do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      result = subject.submit_1010d('uuid', nil)
      # TODO expect...

      # byebug # in byebug, type 'p result' to view the response
    end
  end
end
