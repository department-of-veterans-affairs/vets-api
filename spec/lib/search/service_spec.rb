# frozen_string_literal: true

require 'rails_helper'

describe Search::Service do
  let(:query) { 'benefits' }
  subject { described_class.new(query) }

  before do
    allow_any_instance_of(described_class).to receive(:access_key).and_return('TESTKEY')
  end

  describe '#results' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('search/success', VCR::MATCH_EVERYTHING) do
          response = subject.results

          expect(response).to be_ok
          expect(response).to be_a(Search::ResultsTransactionResponse)
        end
      end

      it 'returns an array of search result data' do
        VCR.use_cassette('search/success') do
          response = subject.results

          query = response.results['query']
          total = response.results['web']['total']

          expect([query, total]).to eq [query, total]
        end
      end
    end
  end
end
