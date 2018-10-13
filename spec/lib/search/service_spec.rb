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

          expect(response.status).to eq 200
          expect(response).to be_a(Search::ResultsResponse)
        end
      end

      it 'returns an array of search result data', :aggregate_failures do
        VCR.use_cassette('search/success', VCR::MATCH_EVERYTHING) do
          response = subject.results

          query = response.body['query']
          total = response.body['web']['total']

          expect([query, total]).to eq [query, total]
        end
      end
    end

    context 'with an offset' do
      let(:query) { 'test' }

      it 'returns the correct segment of results', :aggregate_failures do
        VCR.use_cassette('search/offset') do
          response = subject.results

          next_offset = response.body['pagination']['next']
          prev_offset = response.body['pagination']['previous']

          expect(next_offset).to eq 20
          expect(prev_offset).to eq nil
        end
      end

      it 'returns the correct pagination offsets', :aggregate_failures do
        VCR.use_cassette('search/offset_20') do
          subject = described_class.new(query, '20')
          response = subject.results

          next_offset = response.body['pagination']['next']
          prev_offset = response.body['pagination']['previous']

          expect(next_offset).to eq 40
          expect(prev_offset).to eq nil
        end
      end

      it 'returns the correct pagination offsets', :aggregate_failures do
        VCR.use_cassette('search/offset_40') do
          subject = described_class.new(query, '40')
          response = subject.results

          next_offset = response.body['pagination']['next']
          prev_offset = response.body['pagination']['previous']

          expect(next_offset).to eq 60
          expect(prev_offset).to eq 20
        end
      end

      it 'returns the correct pagination offsets', :aggregate_failures do
        VCR.use_cassette('search/offset_60') do
          subject = described_class.new(query, '60')
          response = subject.results

          next_offset = response.body['pagination']['next']
          prev_offset = response.body['pagination']['previous']

          expect(next_offset).to eq nil
          expect(prev_offset).to eq 40
        end
      end
    end
  end

  context 'with an empty search query' do
    let(:query) { '' }

    it 'raises an exception', :aggregate_failures do
      VCR.use_cassette('search/empty_query', VCR::MATCH_EVERYTHING) do
        expect { subject.results }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(400)
          expect(e.errors.first.code).to eq('SEARCH_400')
        end
      end
    end
  end

  context 'with an invalid API access key' do
    it 'raises an exception', :aggregate_failures do
      VCR.use_cassette('search/invalid_access_key', VCR::MATCH_EVERYTHING) do
        allow_any_instance_of(described_class).to receive(:access_key).and_return('INVALIDKEY')

        expect { subject.results }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(400)
          expect(e.errors.first.code).to eq('SEARCH_400')
        end
      end
    end
  end

  context 'with an invalid affiliate' do
    it 'raises an exception', :aggregate_failures do
      VCR.use_cassette('search/invalid_affiliate', VCR::MATCH_EVERYTHING) do
        allow_any_instance_of(described_class).to receive(:affiliate).and_return('INVALID')

        expect { subject.results }.to raise_error do |e|
          expect(e).to be_a(Common::Exceptions::BackendServiceException)
          expect(e.status_code).to eq(400)
          expect(e.errors.first.code).to eq('SEARCH_400')
        end
      end
    end
  end
end
