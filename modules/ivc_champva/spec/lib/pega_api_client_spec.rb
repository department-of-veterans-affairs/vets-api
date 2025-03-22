# frozen_string_literal: true

require 'rails_helper'
require 'pega_api/client'

RSpec.describe IvcChampva::PegaApi::Client do
  subject { described_class.new }

  describe 'get_report' do
    let(:body200and200) do # pega api response with HTTP status 200 and alternate status 200
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'pega_api_json',
                                     'report_response_200_200.json')
      fixture_path.read
    end

    let(:body200and500) do # pega api response with HTTP status 200 and alternate status 500
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'pega_api_json',
                                     'report_response_200_500.json')
      fixture_path.read
    end

    let(:body403) do # pega api response with HTTP status 403 forbidden
      fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'pega_api_json',
                                     'report_response_403.json')
      fixture_path.read
    end

    context 'successful response from pega' do
      let(:faraday_response) { double('Faraday::Response', status: 200, body: body200and200) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'returns the body as an array of hashes' do
        result = subject.get_report(Date.new(2024, 11, 1), Date.new(2024, 12, 31))

        expect(result[0]['Creation Date']).to eq('2024-11-27T08:42:11.372000')
        expect(result[0]['PEGA Case ID']).to eq('D-55824')
        expect(result[0]['Status']).to eq('Open')
      end
    end

    context 'unsuccessful pega response with bad HTTP status' do
      let(:faraday_response) { double('Faraday::Response', status: 403, body: body403) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'raises error when response is 404' do
        expect { subject.get_report(nil, nil) }.to raise_error(IvcChampva::PegaApi::PegaApiError)
      end
    end

    context 'unsuccessful pega response with bad alternate status' do
      let(:faraday_response) { double('Faraday::Response', status: 200, body: body200and500) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'raises error when alternate status is 500' do
        expect { subject.get_report(nil, nil) }.to raise_error(IvcChampva::PegaApi::PegaApiError)
      end
    end

    context 'when checking record_has_matching_report with a valid form' do
      let(:forms) { create_list(:ivc_champva_form, 1, pega_status: 'Processed', created_at: Date.new(2024, 11, 27)) }
      let(:faraday_response) { double('Faraday::Response', status: 200, body: body200and200) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
      end

      it 'returns an array of results where UUID matches requested record' do
        forms[0].update(form_uuid: '9a0e9790-7e09-46ba-afcb-121a0ddd0d3b')
        result = subject.record_has_matching_report(forms[0])
        expect(result[0]['UUID']).to eq('9a0e9790-7e09-46ba-afcb-121a0e+')
      end
    end
  end

  describe 'headers' do
    it 'returns the right headers' do
      result = subject.headers(Date.new(2024, 11, 1), Date.new(2024, 12, 31))

      expect(result[:content_type]).to eq('application/json')
      expect(result['x-api-key']).to eq('fake_api_key')
      expect(result['date_start']).to eq('2024-11-01')
      expect(result['date_end']).to eq('2024-12-31')
      expect(result['case_id']).to eq('')
      expect(result['uuid']).to eq('')
    end

    it 'returns the right headers with nil dates' do
      result = subject.headers(nil, nil)

      expect(result[:content_type]).to eq('application/json')
      expect(result['x-api-key']).to eq('fake_api_key')
      expect(result['date_start']).to eq('')
      expect(result['date_end']).to eq('')
      expect(result['case_id']).to eq('')
      expect(result['uuid']).to eq('')
    end
  end

  # Temporary, delete me
  # This test is used to hit the production endpoint when running locally.
  # It can be removed once we have some real code that uses the Pega API client.
  describe 'hit the production endpoint', skip: 'this is useful as a way to hit the API during local development' do
    let(:forced_headers) do
      {
        :content_type => 'application/json',
        # use the following line when running locally tp pull the key from an environment variable
        'x-api-key' => ENV.fetch('PEGA_API_KEY'), # to set: export PEGA_API_KEY=insert1the2api3key4here
        'date_start' => '', # '2024-11-01', # '11/01/2024',
        'date_end' => '', # '2024-12-31', # '12/07/2024',
        'case_id' => ''
      }
    end

    before do
      allow_any_instance_of(IvcChampva::PegaApi::Client).to receive(:headers).with(anything, anything)
                                                                             .and_return(forced_headers)
    end

    it 'returns report data' do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      result = subject.get_report(Date.new(2024, 11, 1), Date.new(2024, 12, 31))
      expect(result.count).to be_positive

      # byebug # in byebug, type 'p result' to view the response
    end
  end
end
