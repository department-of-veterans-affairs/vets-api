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

        it 'returns the correct status when MPI is not healthy' do
          allow(MPI::Service).to receive(:service_is_up?).and_return(false)
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['mpi']['success']).to eq(false)
        end

        local_bgs_services = %i[claimant person org ebenefitsbenftclaim intenttofile trackeditem].freeze
        local_bgs_methods = %i[find_poa_by_participant_id find_by_ssn find_poa_history_by_ptcpnt_id
                               find_benefit_claims_status_by_ptcpnt_id insert_intent_to_file find_tracked_items].freeze
        local_bgs_services.each do |local_bgs_service|
          it "returns the correct status when the local bgs #{local_bgs_service} is not healthy" do
            local_bgs_methods.each do |local_bgs_method|
              allow_any_instance_of(ClaimsApi::LocalBGS).to receive(local_bgs_method.to_sym)
                .and_return(Struct.new(:healthy?).new(false))
              get "/services/claims/#{version}/upstream_healthcheck"
              result = JSON.parse(response.body)
              expect(result["localbgs-#{local_bgs_service}"]['success']).to eq(false)
            end
          end
        end

        bgs_services = %i[vet_record corporate_update contention].freeze
        bgs_services.each do |service|
          it "returns the correct status when the BGS #{service} is not healthy" do
            allow_any_instance_of(BGS::Services).to receive(service.to_sym)
              .and_return(Struct.new(:healthy?).new(false))
            get "/services/claims/#{version}/upstream_healthcheck"
            result = JSON.parse(response.body)
            expect(result["bgs-#{service}"]['success']).to eq(false)
          end
        end
      end
    end
  end
end
