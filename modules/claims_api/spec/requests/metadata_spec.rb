# frozen_string_literal: true

require 'rails_helper'
require 'bgs/services'
require 'mpi/service'

RSpec.describe 'ClaimsApi::Metadata', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/claims/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end

  describe '#healthcheck' do
    %w[v1 v2].each do |version|
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

    %w[v1].each do |version|
      context version do
        it 'returns correct response and status when healthy' do
          allow(MPI::Service).to receive(:service_is_up?).and_return(true)
          allow_any_instance_of(BGS::Services).to receive(:vet_record).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(BGS::Services).to receive(:contention).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(BGS::Services).to receive(:corporate_update).and_return(Struct.new(:healthy?).new(true))
          allow_any_instance_of(ClaimsApi::LocalBGS).to receive(:healthcheck).and_return(200)
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(Struct.new(:status).new(200))
          get "/services/claims/#{version}/upstream_healthcheck"
          expect(response).to have_http_status(:ok)
        end

        required_upstream_services = %w[mpi]
        optional_upstream_services = %w[bgs-vet_record bgs-corporate_update bgs-contention
                                        localbgs-healthcheck]
        (required_upstream_services + optional_upstream_services).each do |upstream_service|
          it "returns correct status when #{upstream_service} is not healthy" do
            allow(MPI::Service).to receive(:service_is_up?).and_return(upstream_service != 'mpi')
            allow_any_instance_of(BGS::Services).to receive(:vet_record)
              .and_return(Struct.new(:healthy?).new(upstream_service != 'bgs-vet_record'))
            allow_any_instance_of(BGS::Services).to receive(:corporate_update)
              .and_return(Struct.new(:healthy?).new(upstream_service != 'bgs-corporate_update'))
            allow_any_instance_of(BGS::Services).to receive(:contention)
              .and_return(Struct.new(:healthy?).new(upstream_service != 'bgs-contention'))
            allow_any_instance_of(ClaimsApi::LocalBGS).to receive(:healthcheck)
              .and_return(200)
            get "/services/claims/#{version}/upstream_healthcheck"
            result = JSON.parse(response.body)
            expect(result['mpi']['success']).to eq(false)
            expect(result['bgs-vet_record']['success']).to eq(false)
            expect(result['bgs-corporate_update']['success']).to eq(false)
            expect(result['bgs-contention']['success']).to eq(false)
            expect(result['localbgs-claimant']['success']).to eq(true)
            expect(result['localbgs-person']['success']).to eq(true)
            expect(result['localbgs-org']['success']).to eq(true)
            expect(result['localbgs-ebenefitsbenftclaim']['success']).to eq(true)
            expect(result['localbgs-intenttofile']['success']).to eq(true)
            expect(result['localbgs-trackeditem']['success']).to eq(true)
          end
        end
      end
    end
  end
end
