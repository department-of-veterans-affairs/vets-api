# frozen_string_literal: true

require 'rails_helper'
require 'lib/search/shared_examples_for_pagination'

describe Search::Service do
  let(:query) { 'benefits' }
  subject { described_class.new(query) }

  before do
    allow_any_instance_of(described_class).to receive(:access_key).and_return('TESTKEY')
  end

  describe '#results' do
    context 'when successful' do
      it_behaves_like 'pagination data'

      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('search/success', VCR::MATCH_EVERYTHING) do
          response = subject.results

          expect(response.status).to eq 200
          expect(response).to be_a(Search::ResultsResponse)
        end
      end

      it 'returns an array of search result data' do
        VCR.use_cassette('search/success', VCR::MATCH_EVERYTHING) do
          response = subject.results

          query = response.body['query']
          total = response.body['web']['total']

          expect([query, total]).to eq [query, total]
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

    context 'when exceeding the Search.gov rate limit' do
      it 'raises an exception', :aggregate_failures do
        VCR.use_cassette('search/exceeds_rate_limit', VCR::MATCH_EVERYTHING) do
          expect { subject.results }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::BackendServiceException)
            expect(e.status_code).to eq(429)
            expect(e.errors.first.code).to eq('SEARCH_429')
          end
        end
      end

      it 'should increment the StatsD exception:429 counter' do
        VCR.use_cassette('search/exceeds_rate_limit', VCR::MATCH_EVERYTHING) do
          allow_any_instance_of(described_class).to receive(:raise_backend_exception).and_return(nil)

          expect { subject.results }.to trigger_statsd_increment(
            "#{Search::Service::STATSD_KEY_PREFIX}.exceptions"
          )
        end
      end

      it 'should not log to sentry' do
        VCR.use_cassette('search/exceeds_rate_limit', VCR::MATCH_EVERYTHING) do
          expect_any_instance_of(described_class).to_not receive(:log_message_to_sentry)

          expect { subject.results }.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end
