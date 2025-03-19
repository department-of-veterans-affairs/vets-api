# frozen_string_literal: true

require 'rails_helper'
require 'search_typeahead/service'

# Re-recording VCR Cassettes
# 1. Replace TEST_KEY (`before` block) with Settings.search_typeahead.api_key from Staging
# 2. Delete exsiting cassette file
# 3. Re-run spec
# 4. **IMPORTANT** Replace the API Key with `TEST_KEY` in newly recorded cassettes
#    and `before` block. DON'T PUSH API KEY - (You shouldn't see a diff in either place)

describe SearchTypeahead::Service do
  subject { described_class.new(query) }

  before do
    allow_any_instance_of(described_class).to receive(:api_key).and_return('TEST_KEY')
  end

  describe '#suggestions' do
    context 'when successful' do
      let(:query) { 'ebenefits' }

      it 'returns a status of 200' do
        VCR.use_cassette('search_typeahead/success', VCR::MATCH_EVERYTHING) do
          response = subject.suggestions
          expect(response.status).to eq 200
        end
      end

      it 'returns an array of suggestions' do
        VCR.use_cassette('search_typeahead/success', VCR::MATCH_EVERYTHING) do
          response = subject.suggestions
          expect(JSON.parse(response.body)).to eq [
            'ebenefits direct deposit',
            'ebenefits disability compensation',
            'ebenefits update contact information',
            'ebenefits your records',
            'ebenefits'
          ]
        end
      end
    end

    context 'with a missing parameter' do
      let(:query) { '' }

      it 'returns a status of 200' do
        VCR.use_cassette('search_typeahead/missing_query', VCR::MATCH_EVERYTHING) do
          response = subject.suggestions
          expect(response.status).to eq 200
        end
      end

      it 'returns an empty body' do
        VCR.use_cassette('search_typeahead/missing_query', VCR::MATCH_EVERYTHING) do
          response = subject.suggestions
          expect(response.body).to eq ''
        end
      end
    end

    context 'when a timeout error occurs' do
      let(:query) { 'ebenefits' }

      before do
        allow(Faraday).to receive(:get).and_raise(Faraday::TimeoutError.new('timeout'))
      end

      it 'returns a status of 504 and a timeout error message' do
        response = subject.suggestions
        expect(response.status).to eq 504
        expect(JSON.parse(response.body)['error']).to eq 'The request timed out. Please try again.'
      end
    end

    context 'when a connection error occurs' do
      let(:query) { 'ebenefits' }

      before do
        allow(Faraday).to receive(:get).and_raise(Faraday::ConnectionFailed.new('connection failed'))
      end

      it 'returns a status of 502 and a connection error message' do
        response = subject.suggestions
        expect(response.status).to eq 502
        expect(JSON.parse(response.body)['error']).to eq(
          'Unable to connect to the search service. Please try again later.'
        )
      end
    end

    context 'when an unexpected error occurs' do
      let(:query) { 'ebenefits' }

      before do
        allow(Faraday).to receive(:get).and_raise(StandardError.new('unexpected'))
      end

      it 'returns a status of 500 and a generic error message' do
        response = subject.suggestions
        expect(response.status).to eq 500
        expect(JSON.parse(response.body)['error']).to eq 'An unexpected error occurred.'
      end
    end
  end
end
