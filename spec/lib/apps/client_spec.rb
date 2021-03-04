# frozen_string_literal: true

require 'rails_helper'
require 'apps/client'

describe Apps::Client do
  subject { described_class.new(search_term) }

  let(:search_term) { nil }

  describe '#get_all' do
    context 'with no query' do
      it 'returns an apps response object' do
        VCR.use_cassette('apps/200_all_apps', match_requests_on: %i[method path]) do
          response = subject.get_all
          expect(response).to be_a Apps::Responses::Response
        end
      end
    end
  end

  describe '#get_app' do
    context 'with a query' do
      let(:search_term) { 'iBlueButton' }

      it 'returns an app response object' do
        VCR.use_cassette('apps/200_app_query', match_requests_on: %i[method path]) do
          response = subject.get_app
          expect(response).to be_a Apps::Responses::Response
        end
      end
    end

    context 'with a query that includes whitespace' do
      let(:search_term) { 'Apple Health' }

      it 'returns an app response object' do
        VCR.use_cassette('apps/200_apple_health_query', match_requests_on: %i[method path]) do
          response = subject.get_app
          expect(response).to be_a Apps::Responses::Response
        end
      end
    end
  end

  describe '#get_scopes' do
    context 'with a category passed' do
      let(:search_term) { 'health' }

      it 'returns a scopes response object' do
        VCR.use_cassette('apps/200_scopes_query', match_requests_on: %i[method path]) do
          response = subject.get_scopes
          expect(response).to be_a Apps::Responses::Response
        end
      end
    end

    context 'with an empty category' do
      let(:search_term) { nil }

      it 'returns a 204' do
        VCR.use_cassette('apps/204_scopes_query', match_requests_on: %i[method path]) do
          response = subject.get_scopes
          expect(response.status).to be(204)
        end
      end
    end
  end

  context 'with an http timeout' do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
    end

    it 'logs an error and raise GatewayTimeout exception' do
      expect(StatsD).to receive(:increment).once.with(
        'api.apps.get_all.fail', tags: ['error:CommonExceptionsGatewayTimeout']
      )
      expect(StatsD).to receive(:increment).once.with('api.apps.get_all.total')
      expect { subject.get_all }.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  context 'with a client error' do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Common::Client::Errors::ClientError)
    end

    it 'raises backend exception' do
      expect(StatsD).to receive(:increment).once.with(
        'api.apps.get_all.fail', tags: ['error:CommonClientErrorsClientError']
      )
      expect(StatsD).to receive(:increment).once.with('api.apps.get_all.total')
      expect { subject.get_all }.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end
end
