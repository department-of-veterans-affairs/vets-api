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
  end
end
