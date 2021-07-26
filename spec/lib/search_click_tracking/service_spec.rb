# frozen_string_literal: true

require 'rails_helper'
# require 'search_click_tracking/service'

describe SearchClickTracking::Service do
  subject { described_class.new(url, query, position, user_agent, module_code) }

  before do
    allow_any_instance_of(described_class).to receive(:access_key).and_return('TESTKEY')
  end

  let(:user_agent) { 'testUserAgent' }
  let(:position) { '0' }
  let(:url) { 'https://www.testurl.com' }
  let(:module_code) { 'I14Y' }

  describe '#track_click' do
    context 'when successful' do
      let(:query) { 'testQuery' }

      it 'returns a status of 200' do
        VCR.use_cassette('search_click_tracking/success', VCR::MATCH_EVERYTHING) do
          response = subject.track_click
          expect(response.status).to eq 200
        end
      end

      it 'returns an empty body' do
        VCR.use_cassette('search_click_tracking/success', VCR::MATCH_EVERYTHING) do
          response = subject.track_click
          expect(response.body).to eq ''
        end
      end
    end

    context 'with a missing parameter' do
      let(:query) { '' }

      it 'returns a status of 400', :aggregate_failures do
        VCR.use_cassette('search_click_tracking/missing_parameter', VCR::MATCH_EVERYTHING) do
          response = subject.track_click
          expect(response.status).to eq(400)
          expect(response.body).to eq "[\"Query can\'t be blank\"]"
        end
      end
    end
  end
end
