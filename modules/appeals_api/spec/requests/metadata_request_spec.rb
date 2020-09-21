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

  describe '#downstream_healthcheck' do
    let(:health_check_stub) do
      health_checker = instance_double(AppealsApi::HealthChecker)
      allow(AppealsApi::HealthChecker).to receive(:new).and_return(health_checker)
      health_checker
    end

    before do
      time = Time.utc(2020, 9, 21, 0, 0, 0)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    context 'v0' do
      it 'returns correct response and status when healthy' do
        allow(health_check_stub).to receive(:services_are_healthy?).and_return(true)
        allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(true)

        get '/services/appeals/v0/downstream_healthcheck'
        expect(response).to have_http_status(:ok)

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('Appeals API downstream health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All downstream services')

        downstream_service = details['downstreamServices'].first
        expect(details['downstreamServices'].size).to eq(1)
        expect(downstream_service['description']).to eq('Caseflow')
        expect(downstream_service['status']).to eq('UP')
        expect(downstream_service['details']['name']).to eq('Caseflow')
        expect(downstream_service['details']['statusCode']).to eq(200)
        expect(downstream_service['details']['status']).to eq('OK')
        expect(downstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end

      it 'returns correct status when caseflow is not healthy' do
        allow(health_check_stub).to receive(:services_are_healthy?).and_return(false)
        allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(false)

        get '/services/appeals/v0/downstream_healthcheck'
        expect(response).to have_http_status(:service_unavailable)

        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('Appeals API downstream health check')
        expect(parsed_response['status']).to eq('DOWN')
        expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

        details = parsed_response['details']
        expect(details['name']).to eq('All downstream services')

        downstream_service = details['downstreamServices'].first
        expect(details['downstreamServices'].size).to eq(1)
        expect(downstream_service['description']).to eq('Caseflow')
        expect(downstream_service['status']).to eq('DOWN')
        expect(downstream_service['details']['name']).to eq('Caseflow')
        expect(downstream_service['details']['statusCode']).to eq(503)
        expect(downstream_service['details']['status']).to eq('Unavailable')
        expect(downstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      end

      context 'v1' do
        it 'returns correct response and status when healthy' do
          allow(health_check_stub).to receive(:services_are_healthy?).and_return(true)
          allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(true)

          get '/services/appeals/v1/downstream_healthcheck'
          expect(response).to have_http_status(:ok)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API downstream health check')
          expect(parsed_response['status']).to eq('UP')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All downstream services')

          downstream_service = details['downstreamServices'].first
          expect(details['downstreamServices'].size).to eq(1)
          expect(downstream_service['description']).to eq('Caseflow')
          expect(downstream_service['status']).to eq('UP')
          expect(downstream_service['details']['name']).to eq('Caseflow')
          expect(downstream_service['details']['statusCode']).to eq(200)
          expect(downstream_service['details']['status']).to eq('OK')
          expect(downstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end

        it 'returns correct status when caseflow is not healthy' do
          allow(health_check_stub).to receive(:services_are_healthy?).and_return(false)
          allow(health_check_stub).to receive(:caseflow_is_healthy?).and_return(false)

          get '/services/appeals/v1/downstream_healthcheck'
          expect(response).to have_http_status(:service_unavailable)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Appeals API downstream health check')
          expect(parsed_response['status']).to eq('DOWN')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All downstream services')

          downstream_service = details['downstreamServices'].first
          expect(details['downstreamServices'].size).to eq(1)
          expect(downstream_service['description']).to eq('Caseflow')
          expect(downstream_service['status']).to eq('DOWN')
          expect(downstream_service['details']['name']).to eq('Caseflow')
          expect(downstream_service['details']['statusCode']).to eq(503)
          expect(downstream_service['details']['status']).to eq('Unavailable')
          expect(downstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
        end
      end
    end
  end
end
