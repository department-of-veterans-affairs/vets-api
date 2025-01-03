# frozen_string_literal: true

require 'rails_helper'
require 'bgs/services'
require 'mpi/service'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'
require 'bgs_service/org_web_service'
require 'bgs_service/intent_to_file_web_service'
require 'bgs_service/person_web_service'

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

        local_bgs_services = %i[claimant trackeditem].freeze
        local_bgs_methods = %i[find_poa_by_participant_id
                               find_tracked_items].freeze
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

        local_bgs_claims_status_services = %i[ebenefitsbenftclaim]
        local_bgs_claims_status_methods = %i[find_benefit_claims_status_by_ptcpnt_id]
        local_bgs_claims_status_services.each do |local_bgs_claims_status_service|
          it "returns the correct status when the local bgs #{local_bgs_claims_status_service} is not healthy" do
            local_bgs_claims_status_methods.each do |local_bgs_claims_status_method|
              allow_any_instance_of(ClaimsApi::EbenefitsBnftClaimStatusWebService).to receive(
                local_bgs_claims_status_method.to_sym
              )
                .and_return(Struct.new(:healthy?).new(false))
              get "/services/claims/#{version}/upstream_healthcheck"
              result = JSON.parse(response.body)
              expect(result["localbgs-#{local_bgs_claims_status_service}"]['success']).to eq(false)
            end
          end
        end

        local_bgs_org_methods = %i[find_poa_history_by_ptcpnt_id]
        it 'returns the correct status when the local bgs orgwebservice is not healthy' do
          local_bgs_org_methods.each do |local_bgs_org_method|
            allow_any_instance_of(ClaimsApi::OrgWebService).to receive(
              local_bgs_org_method.to_sym
            )
              .and_return(Struct.new(:healthy?).new(false))
            get "/services/claims/#{version}/upstream_healthcheck"
            result = JSON.parse(response.body)
            expect(result['localbgs-org']['success']).to eq(false)
          end
        end

        local_bgs_itf_methods = %i[insert_intent_to_file]
        it 'returns the correct status when the local bgs intenttofile is not healthy' do
          local_bgs_itf_methods.each do |local_bgs_itf_method|
            allow_any_instance_of(ClaimsApi::IntentToFileWebService).to receive(
              local_bgs_itf_method.to_sym
            )
              .and_return(Struct.new(:healthy?).new(false))
            get "/services/claims/#{version}/upstream_healthcheck"
            result = JSON.parse(response.body)
            expect(result['localbgs-intenttofile']['success']).to eq(false)
          end
        end

        person_web_service = 'person'
        local_bgs_person_methods = %i[find_by_ssn]
        it "returns the correct status when the local bgs #{person_web_service} is not healthy" do
          local_bgs_person_methods.each do |local_bgs_person_method|
            allow_any_instance_of(ClaimsApi::PersonWebService).to receive(
              local_bgs_person_method.to_sym
            )
              .and_return(Struct.new(:healthy?).new(false))
            get "/services/claims/#{version}/upstream_healthcheck"
            result = JSON.parse(response.body)
            expect(result["localbgs-#{person_web_service}"]['success']).to eq(false)
          end
        end
      end
    end
  end
end
