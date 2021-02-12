# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/health_checker'

RSpec.describe 'Appeals Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns decision reviews metadata JSON' do
      get '/services/appeals/decision_reviews/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end

    it 'returns appeals status metadata JSON' do
      get '/services/appeals/appeals_status/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#healthcheck' do
    context 'v0' do
      it 'returns a successful health check' do
        get '/services/appeals/v0/healthcheck'

        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response['description']).to eq('Appeals API health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).not_to be_nil
      end
    end

    context 'v1' do
      it 'returns a successful health check' do
        get '/services/appeals/v1/healthcheck'

        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response['description']).to eq('Appeals API health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).not_to be_nil
      end
    end
  end

  describe '#upstream_healthcheck' do
    before do
      time = Time.utc(2020, 9, 21, 0, 0, 0)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    context 'v0' do
      it 'returns correct response and status when healthy' do
        VCR.use_cassette('caseflow/health-check') do
          get '/services/appeals/v0/upstream_healthcheck'
          expect(response).to have_http_status(:ok)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API upstream health check')
          expect(parsed_response['status']).to eq('UP')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].first
          expect(details['upstreamServices'].size).to eq(1)
          expect(upstream_service['description']).to eq('Caseflow')
          expect(upstream_service['status']).to eq('UP')
          expect(upstream_service['details']['name']).to eq('Caseflow')
          expect(upstream_service['details']['statusCode']).to eq(200)
          expect(upstream_service['details']['status']).to eq('OK')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end

      it 'returns correct status when caseflow is not healthy' do
        VCR.use_cassette('caseflow/health-check-down') do
          get '/services/appeals/v0/upstream_healthcheck'
          expect(response).to have_http_status(:service_unavailable)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API upstream health check')
          expect(parsed_response['status']).to eq('DOWN')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].first
          expect(details['upstreamServices'].size).to eq(1)
          expect(upstream_service['description']).to eq('Caseflow')
          expect(upstream_service['status']).to eq('DOWN')
          expect(upstream_service['details']['name']).to eq('Caseflow')
          expect(upstream_service['details']['statusCode']).to eq(503)
          expect(upstream_service['details']['status']).to eq('Unavailable')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end
    end

    context 'v1' do
      it 'checks the status of both services individually' do
        VCR.use_cassette('caseflow/health-check') do
          allow(CentralMail::Service).to receive(:current_breaker_outage?).and_return(true)

          get '/services/appeals/v1/upstream_healthcheck'
          parsed_response = JSON.parse(response.body)

          caseflow = parsed_response['details']['upstreamServices'].first
          central_mail = parsed_response['details']['upstreamServices'].last

          expect(response).to have_http_status(:service_unavailable)
          expect(caseflow['status']).to eq('UP')
          expect(central_mail['status']).to eq('DOWN')
        end
      end

      it 'returns correct response and status when healthy' do
        VCR.use_cassette('caseflow/health-check') do
          allow(CentralMail::Service).to receive(:current_breaker_outage?).and_return(false)

          get '/services/appeals/v1/upstream_healthcheck'
          expect(response).to have_http_status(:ok)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API upstream health check')
          expect(parsed_response['status']).to eq('UP')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].first
          expect(details['upstreamServices'].size).to eq(2)
          expect(upstream_service['description']).to eq('Caseflow')
          expect(upstream_service['status']).to eq('UP')
          expect(upstream_service['details']['name']).to eq('Caseflow')
          expect(upstream_service['details']['statusCode']).to eq(200)
          expect(upstream_service['details']['status']).to eq('OK')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end

      it 'returns correct status when caseflow is not healthy' do
        VCR.use_cassette('caseflow/health-check-down') do
          allow(CentralMail::Service).to receive(:current_breaker_outage?).and_return(false)

          get '/services/appeals/v1/upstream_healthcheck'
          expect(response).to have_http_status(:service_unavailable)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API upstream health check')
          expect(parsed_response['status']).to eq('DOWN')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].first
          expect(details['upstreamServices'].size).to eq(2)
          expect(upstream_service['description']).to eq('Caseflow')
          expect(upstream_service['status']).to eq('DOWN')
          expect(upstream_service['details']['name']).to eq('Caseflow')
          expect(upstream_service['details']['statusCode']).to eq(503)
          expect(upstream_service['details']['status']).to eq('Unavailable')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end

      it 'returns the correct status when CentralMail is not healthy' do
        VCR.use_cassette('caseflow/health-check') do
          allow(CentralMail::Service).to receive(:current_breaker_outage?).and_return(true)

          get '/services/appeals/v1/upstream_healthcheck'
          expect(response).to have_http_status(:service_unavailable)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API upstream health check')
          expect(parsed_response['status']).to eq('DOWN')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].last
          expect(details['upstreamServices'].size).to eq(2)
          expect(upstream_service['description']).to eq('Central Mail')
          expect(upstream_service['status']).to eq('DOWN')
          expect(upstream_service['details']['name']).to eq('Central Mail')
          expect(upstream_service['details']['statusCode']).to eq(503)
          expect(upstream_service['details']['status']).to eq('Unavailable')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end

      it 'returns correct status when CentralMail is healthy' do
        VCR.use_cassette('caseflow/health-check') do
          allow(CentralMail::Service).to receive(:current_breaker_outage?).and_return(false)

          get '/services/appeals/v1/upstream_healthcheck'
          expect(response).to have_http_status(:ok)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API upstream health check')
          expect(parsed_response['status']).to eq('UP')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].last
          expect(details['upstreamServices'].size).to eq(2)
          expect(upstream_service['description']).to eq('Central Mail')
          expect(upstream_service['status']).to eq('UP')
          expect(upstream_service['details']['name']).to eq('Central Mail')
          expect(upstream_service['details']['statusCode']).to eq(200)
          expect(upstream_service['details']['status']).to eq('OK')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end
    end
  end
end
