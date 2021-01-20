# frozen_string_literal: true

require 'rails_helper'
require 'bgs/service'
require 'mpi/service'
require 'evss/service'

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
          expect(parsed_response['default']['message']).to eq('Application is running')
          expect(parsed_response['default']['success']).to eq(true)
          expect(parsed_response['default']['time']).not_to be_nil
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
          allow(EVSS::Service).to receive(:service_is_up?).and_return(true)
          allow(MPI::Service).to receive(:service_is_up?).and_return(true)
          allow_any_instance_of(BGS::Services).to receive(:vet_record).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(Struct.new(:status).new(200))
          get "/services/claims/#{version}/upstream_healthcheck"
          expect(response).to have_http_status(:ok)
        end

        %w[evss mpi bgs vbms].each do |upstream_service|
          it "returns correct status when #{upstream_service} is not healthy" do
            allow(EVSS::Service).to receive(:service_is_up?).and_return(upstream_service != 'evss')
            allow(MPI::Service).to receive(:service_is_up?).and_return(upstream_service != 'mpi')
            allow_any_instance_of(BGS::Services).to receive(:vet_record)
              .and_return(Struct.new(:healthy?).new(upstream_service != 'bgs'))
            allow_any_instance_of(Faraday::Connection).to receive(:get)
              .and_return(upstream_service == 'vbms' ? Struct.new(:status).new(500) : Struct.new(:status).new(200))
            get "/services/claims/#{version}/upstream_healthcheck"
            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end
    end
  end
end
