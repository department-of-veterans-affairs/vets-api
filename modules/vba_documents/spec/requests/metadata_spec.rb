# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/health_checker'

RSpec.describe 'VBADocument::V1::Metadata', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/vba_documents/metadata'
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#upstream_healthcheck' do
    let(:path) { '/services/vba_documents/v1/upstream_healthcheck' }
    let(:health_checker) { instance_double(VBADocuments::HealthChecker) }

    before do
      time = Time.utc(2025, 2, 18, 0, 0, 0)
      Timecop.freeze(time)

      allow(VBADocuments::HealthChecker).to receive(:new).and_return(health_checker)
    end

    after { Timecop.return }

    context 'when central mail is healthy' do
      before do
        allow(health_checker).to receive(:services_are_healthy?).and_return(true)
        allow(health_checker).to receive(:healthy_service?).with('central_mail').and_return(true)
        get path
      end

      it 'returns a 200 response' do
        expect(response).to have_http_status(:ok)
      end

      it 'includes high-level status information in the response body' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
        expect(parsed_response['status']).to eq('UP')
        expect(parsed_response['time']).to eq('2025-02-18T00:00:00Z')
        expect(parsed_response['details']['name']).to eq('All upstream services')
      end

      it 'includes central mail status information in the response body' do
        upstream_service = JSON.parse(response.body)['details']['upstreamServices'].first
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('UP')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(200)
        expect(upstream_service['details']['status']).to eq('OK')
        expect(upstream_service['details']['time']).to eq('2025-02-18T00:00:00Z')
      end
    end

    context 'when central mail is not healthy' do
      before do
        allow(health_checker).to receive(:services_are_healthy?).and_return(false)
        allow(health_checker).to receive(:healthy_service?).with('central_mail').and_return(false)
        get path
      end

      it 'returns a 503 response' do
        expect(response).to have_http_status(:service_unavailable)
      end

      it 'includes high-level status information in the response body' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['description']).to eq('VBA Documents API upstream health check')
        expect(parsed_response['status']).to eq('DOWN')
        expect(parsed_response['time']).to eq('2025-02-18T00:00:00Z')
        expect(parsed_response['details']['name']).to eq('All upstream services')
      end

      it 'includes central mail status information in the response body' do
        upstream_service = JSON.parse(response.body)['details']['upstreamServices'].first
        expect(upstream_service['description']).to eq('Central Mail')
        expect(upstream_service['status']).to eq('DOWN')
        expect(upstream_service['details']['name']).to eq('Central Mail')
        expect(upstream_service['details']['statusCode']).to eq(503)
        expect(upstream_service['details']['status']).to eq('Unavailable')
        expect(upstream_service['details']['time']).to eq('2025-02-18T00:00:00Z')
      end
    end
  end
end
