# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/health_checker'

RSpec.describe 'Claims Status Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/claims/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#healthcheck' do
    %w[v0 v1].each do |version|
      context version do
        it 'returns a successful health check' do
          get "/services/claims/#{version}/healthcheck"

          parsed_response = JSON.parse(response.body)
          expect(response).to have_http_status(:ok)
          expect(parsed_response['description']).to eq('Claims API health check')
          expect(parsed_response['status']).to eq('UP')
          expect(parsed_response['time']).not_to be_nil
        end
      end
    end
  end

  describe '#upstream_healthcheck' do
    before do
      time = Time.utc(2020, 9, 21, 0, 0, 0)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    %w[v0 v1].each do |version|
      context version do
        it 'returns correct response and status when healthy' do
          allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?).and_return(true)
          allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:mpi_is_healthy?).and_return(true)
          allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?).and_return(true)
          allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?).and_return(true)
          get "/services/claims/#{version}/upstream_healthcheck"
          expect(response).to have_http_status(:ok)

          parsed_response = JSON.parse(response.body)
          expect(parsed_response['description']).to eq('Claims API upstream health check')
          expect(parsed_response['status']).to eq('UP')
          expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

          details = parsed_response['details']
          expect(details['name']).to eq('All upstream services')

          expect(details['upstreamServices'].size).to eq(4)
          details['upstreamServices'].each do |upstream_service|
            expect(upstream_service['description']).to be_in(ClaimsApi::HealthChecker::SERVICES.map(&:upcase))
            expect(upstream_service['status']).to eq('UP')
            expect(upstream_service['details']['name']).to be_in(ClaimsApi::HealthChecker::SERVICES.map(&:upcase))
            expect(upstream_service['details']['statusCode']).to eq(200)
            expect(upstream_service['details']['status']).to eq('OK')
            expect(upstream_service['details']['time']).to eq('2020-09-21T00:00:00Z')
          end
        end

        ClaimsApi::HealthChecker::SERVICES.each do |upstream_service|
          it "returns correct status when #{upstream_service} is not healthy" do
            allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:evss_is_healthy?)
              .and_return(upstream_service != 'evss')
            allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:mpi_is_healthy?)
              .and_return(upstream_service != 'mpi')
            allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:bgs_is_healthy?)
              .and_return(upstream_service != 'bgs')
            allow_any_instance_of(ClaimsApi::HealthChecker).to receive(:vbms_is_healthy?)
              .and_return(upstream_service != 'vbms')
            get "/services/claims/#{version}/upstream_healthcheck"
            expect(response).to have_http_status(:service_unavailable)

            parsed_response = JSON.parse(response.body)
            expect(parsed_response['description']).to eq('Claims API upstream health check')
            expect(parsed_response['status']).to eq('DOWN')
            expect(parsed_response['time']).to eq('2020-09-21T00:00:00Z')

            details = parsed_response['details']
            expect(details['name']).to eq('All upstream services')

            expect(details['upstreamServices'].size).to eq(4)
            details['upstreamServices'].each do |service_response|
              service_under_test = service_response['description'] == upstream_service.upcase

              expect(service_response['description']).to be_in(ClaimsApi::HealthChecker::SERVICES.map(&:upcase))
              expect(service_response['status']).to eq(service_under_test ? 'DOWN' : 'UP')
              expect(service_response['details']['name']).to be_in(ClaimsApi::HealthChecker::SERVICES.map(&:upcase))
              expect(service_response['details']['statusCode']).to eq(service_under_test ? 503 : 200)
              expect(service_response['details']['status']).to eq(service_under_test ? 'Unavailable' : 'OK')
              expect(service_response['details']['time']).to eq('2020-09-21T00:00:00Z')
            end
          end
        end
      end
    end
  end
end
