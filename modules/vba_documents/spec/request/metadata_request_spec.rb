# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/health_checker'

RSpec.describe 'VBA Documents Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/vba_documents/metadata'
      expect(response).to have_http_status(:ok)
    end
  end

  # context 'healthchecks' do
  #   context 'V0' do
  #     it 'returns correct response and status when healthy' do
  #       get '/services/vba_documents/v0/healthcheck'
  #       parsed_response = JSON.parse(response.body)
  #       expect(response.status).to eq(200)
  #       expect(parsed_response['data']['attributes']['healthy']).to eq(true)
  #     end
  #
  #     it 'returns correct status when not healthy' do
  #       allow(CentralMail::Service).to receive(:current_breaker_outage?).and_return(true)
  #       get '/services/vba_documents/v0/healthcheck'
  #       expect(response.status).to eq(503)
  #     end
  #   end
  #
  #   context 'V1' do
  #     it 'returns correct response and status when healthy' do
  #       get '/services/vba_documents/v1/healthcheck'
  #       parsed_response = JSON.parse(response.body)
  #       expect(response.status).to eq(200)
  #       expect(parsed_response['data']['attributes']['healthy']).to eq(true)
  #     end
  #
  #     it 'returns correct status when not healthy' do
  #       allow(CentralMail::Service).to receive(:current_breaker_outage?).and_return(true)
  #       get '/services/vba_documents/v1/healthcheck'
  #       expect(response.status).to eq(503)
  #     end
  #   end
  # end

  describe '#healthcheck' do
    context 'v0' do
      it 'returns a successful health check' do
        get '/services/vba_documents/v0/healthcheck'

        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response['description']).to eq('VBA Documents API health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).not_to be_nil
      end
    end

    context 'v1' do
      it 'returns a successful health check' do
        get '/services/vba_documents/v1/healthcheck'

        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(parsed_response['description']).to eq('VBA Documents API health check')
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
        expect(CentralMail::Service).to receive(:current_breaker_outage?).at_least(:once).and_return(true)
        get '/services/vba_documents/v0/upstream_healthcheck'
        expect(response).to have_http_status(:ok)

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        upstream_service = details['upstreamServices'].first
        expect(details['upstreamServices'].size).to eq(1)
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('UP')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(200)
        expect(upstream_service['details']['status']).to eq('OK')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end

      it 'returns correct status when central_mail is not healthy' do
        expect(CentralMail::Service).to receive(:current_breaker_outage?).at_least(:once).and_return(false)
        get '/services/vba_documents/v0/upstream_healthcheck'
        expect(response).to have_http_status(:service_unavailable)

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
        expect(parsed_response['status']).to eq('DOWN')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All upstream services')

        upstream_service = details['upstreamServices'].first
        expect(details['upstreamServices'].size).to eq(1)
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('DOWN')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(503)
        expect(upstream_service['details']['status']).to eq('Unavailable')
        expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end

      context 'v1' do
        it 'returns correct response and status when healthy' do
          expect(CentralMail::Service).to receive(:current_breaker_outage?).at_least(:once).and_return(true)
          get '/services/vba_documents/v1/upstream_healthcheck'
          expect(response).to have_http_status(:ok)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
          expect(parsed_response['status']).to eq('UP')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].first
          expect(details['upstreamServices'].size).to eq(1)
          expect(upstream_service['description']).to eq('Central Mail')
          expect(upstream_service['status']).to eq('UP')
          expect(upstream_service['details']['name']).to eq('Central Mail')
          expect(upstream_service['details']['statusCode']).to eq(200)
          expect(upstream_service['details']['status']).to eq('OK')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end

        it 'returns correct status when central_mail is not healthy' do
          expect(CentralMail::Service).to receive(:current_breaker_outage?).at_least(:once).and_return(false)
          get '/services/vba_documents/v1/upstream_healthcheck'
          expect(response).to have_http_status(:service_unavailable)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
          expect(parsed_response['status']).to eq('DOWN')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          upstream_service = details['upstreamServices'].first
          expect(details['upstreamServices'].size).to eq(1)
          expect(upstream_service['description']).to eq('Central Mail')
          expect(upstream_service['status']).to eq('DOWN')
          expect(upstream_service['details']['name']).to eq('Central Mail')
          expect(upstream_service['details']['statusCode']).to eq(503)
          expect(upstream_service['details']['status']).to eq('Unavailable')
          expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end
    end
  end
end
