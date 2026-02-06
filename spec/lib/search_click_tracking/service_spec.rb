# frozen_string_literal: true

require 'rails_helper'
require 'rack/utils'
# require 'search_click_tracking/service'

# Rerecording VCR Cassettes
# 1. Replace TEST_KEY (`before` block) with Settings.search_click_tracking.access_key from Staging
# 2. Delete exsiting cassette file
# 3. Re-run spec
# 4. **IMPORTANT** Replace the Access Key with `TEST_KEY` in newly recorded cassettes
#    and `before` block. DON'T PUSH Access KEY - (You shouldn't see a diff in either place)

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
          expect(response.body).to eq "[\"Query can't be blank\"]"
        end
      end
    end
  end

  describe '#query_params' do
    let(:query) { 'test@example.com' }
    let(:user_agent) { 'agent 555-123-4567' }
    let(:url) { 'https://www.testurl.com?email=test@example.com' }

    it 'redacts PII in query, url, and user_agent' do
      params = Rack::Utils.parse_nested_query(subject.send(:query_params))

      expect(params['query']).to eq('[REDACTED - email]')
      expect(params['url']).to include('[REDACTED - email]')
      expect(params['user_agent']).to include('[REDACTED - phone]')
      expect(params['url']).not_to include('test@example.com')
      expect(params['user_agent']).not_to include('555-123-4567')
    end
  end
end
