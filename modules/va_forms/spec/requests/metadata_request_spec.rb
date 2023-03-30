# frozen_string_literal: true

require 'rails_helper'
require 'va_forms/health_checker'

RSpec.describe 'VA Forms Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/va_forms/metadata'
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#healthchecks' do
    def common_health_checks
      get '/services/va_forms/v0/healthcheck'
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(parsed_response['description']).to eq(VAForms::HealthChecker::HEALTH_DESCRIPTION)
      expect(parsed_response['status']).to eq('UP')
      expect(parsed_response['time']).not_to be_nil
    end

    context 'v0' do
      it 'returns correct response and status when healthy' do
        allow(VAForms::Form).to receive(:count).and_return(1)
        common_health_checks
      end

      it 'returns UP status even when upstream is not healthy' do
        common_health_checks
      end
    end
  end

  describe '#upstream_healthcheck' do
    before do
      time = Time.utc(2020, 9, 21, 0, 0, 0)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    def common_upstream_health_checks(path)
      get path
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['description']).to eq(VAForms::HealthChecker::HEALTH_DESCRIPTION_UPSTREAM)
      expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

      details = parsed_response['details']
      expect(details['name']).to eq('All upstream services')

      upstream_service = details['upstreamServices'].first
      expect(details['upstreamServices'].size).to eq(1)
      expect(upstream_service['description']).to eq(VAForms::HealthChecker::CMS_SERVICE)
      expect(upstream_service['details']['name']).to eq(VAForms::HealthChecker::CMS_SERVICE)
      expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
      { parsed_response:, upstream_service: }
    end

    def healthy_checks(path)
      allow(VAForms::Form).to receive(:count).and_return(1)
      results = common_upstream_health_checks(path)
      expect(response).to have_http_status(:ok)
      parsed_response = results[:parsed_response]
      upstream_service = results[:upstream_service]
      expect(parsed_response['status']).to eq('UP')
      expect(upstream_service['status']).to eq('UP')
      expect(upstream_service['details']['statusCode']).to eq(200)
      expect(upstream_service['details']['status']).to eq('OK')
    end

    def unhealthy_checks(path)
      results = common_upstream_health_checks(path)
      expect(response).to have_http_status(:service_unavailable)
      parsed_response = results[:parsed_response]
      upstream_service = results[:upstream_service]
      expect(parsed_response['status']).to eq('DOWN')
      expect(upstream_service['status']).to eq('DOWN')
      expect(upstream_service['details']['statusCode']).to eq(503)
      expect(upstream_service['details']['status']).to eq('Unavailable')
    end

    context 'v0' do
      path = '/services/va_forms/v0/upstream_healthcheck'
      it 'returns correct response and status when healthy' do
        healthy_checks(path)
      end

      it 'returns correct status when cms is not healthy' do
        unhealthy_checks(path)
      end
    end
  end
end
