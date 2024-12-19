# frozen_string_literal: true

require 'rails_helper'
require 'bgs/services'
require 'mpi/service'
require 'bgs_service/local_bgs'
require 'bgs_service/benefit_claim_service'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'
require 'bgs_service/claimant_web_service'
require 'bgs_service/claim_management_service'
require 'bgs_service/contention_service'
require 'bgs_service/corporate_update_web_service'
require 'bgs_service/intent_to_file_web_service'
require 'bgs_service/manage_representative_service'
require 'bgs_service/person_web_service'
require 'bgs_service/standard_data_service'
require 'bgs_service/vet_record_web_service'
require 'bgs_service/vnp_atchms_service'
require 'bgs_service/vnp_person_service'
require 'bgs_service/vnp_proc_form_service'
require 'bgs_service/vnp_proc_service_v2'
require 'bgs_service/vnp_ptcpnt_addrs_service'
require 'bgs_service/vnp_ptcpnt_phone_service'
require 'bgs_service/vnp_ptcpnt_service'

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

        it 'returns the correct status when the benefit-claim-service is not healthy' do
          allow_any_instance_of(ClaimsApi::BenefitClaimService).to receive(
            :update_benefit_claim
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['benefit-claim-web-service']['success']).to eq(false)
        end

        it 'returns the correct status when the e-benefits-bnft-claim-status-web-service is not healthy' do
          allow_any_instance_of(ClaimsApi::EbenefitsBnftClaimStatusWebService).to receive(
            :find_benefit_claims_status_by_ptcpnt_id
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['e-benefits-bnft-claim-status-web-service']['success']).to eq(false)
        end

        it 'returns the correct status when the claimant service is not healthy' do
          allow_any_instance_of(ClaimsApi::ClaimantWebService).to receive(
            :find_poa_by_participant_id
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['claimant-service']['success']).to eq(false)
        end

        it 'returns the correct status when the claim_management_service is not healthy' do
          allow_any_instance_of(ClaimsApi::ClaimManagementService).to receive(
            :find_claim_level_suspense
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['claim-management-service']['success']).to eq(false)
        end

        it 'returns the correct status when the contention_service is not healthy' do
          allow_any_instance_of(ClaimsApi::ContentionService).to receive(
            :find_contentions_by_ptcpnt_id
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['contention-service']['success']).to eq(false)
        end

        it 'returns the correct status when the corporate_update_web_service is not healthy' do
          allow_any_instance_of(ClaimsApi::CorporateUpdateWebService).to receive(
            :update_poa_access
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['corporate-update-web-service']['success']).to eq(false)
        end

        it 'returns the correct status when the intenttofile is not healthy' do
          allow_any_instance_of(ClaimsApi::IntentToFileWebService).to receive(
            :insert_intent_to_file
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['intent-to-file-service']['success']).to eq(false)
        end

        it 'returns the correct status when the manage rep service is not healthy' do
          allow_any_instance_of(ClaimsApi::ManageRepresentativeService).to receive(
            :update_poa_request
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['manage-rep-service']['success']).to eq(false)
        end

        it 'returns the correct status when bgs org service is not healthy' do
          allow_any_instance_of(ClaimsApi::LocalBGS).to receive(
            :find_poa_history_by_ptcpnt_id
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['localbgs-org']['success']).to eq(false)
        end

        it 'returns the correct status when the person_web_service is not healthy' do
          allow_any_instance_of(ClaimsApi::PersonWebService).to receive(
            :find_by_ssn
          )
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['person-web-service']['success']).to eq(false)
        end

        it 'returns the correct status when the bgs standard_data_service is not healthy' do
          allow_any_instance_of(ClaimsApi::StandardDataService).to receive(:get_contention_classification_type_code_list)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['standard-data-service']['success']).to eq(false)
        end

        it 'returns the correct status when the bgs trackeditem is not healthy' do
          allow_any_instance_of(ClaimsApi::LocalBGS).to receive(:find_tracked_items)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['localbgs-trackeditem']['success']).to eq(false)
        end

        it 'returns the correct status when the bgs vet-record service is not healthy' do
          allow_any_instance_of(ClaimsApi::VetRecordWebService).to receive(:update_birls_record)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vet-record-service']['success']).to eq(false)
        end

        # 'bgs_service/vnp_atchms_service'
        it 'returns the correct status when the bgs vnp_atchms_service is not healthy' do
          allow_any_instance_of(ClaimsApi::VnpAtchmsService).to receive(:vnp_atchms_create)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp-atchms-web-service']['success']).to eq(false)
        end

        # 'bgs_service/vnp_person_service'
        it 'returns the correct status when the bgs vnp_person_service is not healthy' do
          allow_any_instance_of(ClaimsApi::VnpPersonService).to receive(:vnp_person_create)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp-person-web-service']['success']).to eq(false)
        end

        # 'bgs_service/vnp_proc_form_service'
        it 'returns the correct status when the bgs vnp_proc_form_service is not healthy' do
          allow_any_instance_of(ClaimsApi::VnpProcFormService).to receive(:vnp_proc_form_create)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp-proc-form-web-service']['success']).to eq(false)
        end

        # 'bgs_service/vnp_proc_service_v2'
        it 'returns the correct status when the bgs vnp_proc_service_v2 is not healthy' do
          allow_any_instance_of(ClaimsApi::VnpProcServiceV2).to receive(:vnp_proc_create)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp-proc-service-v2']['success']).to eq(false)
        end

        # 'bgs_service/vnp_ptcpnt_addrs_service'
        it 'returns the correct status when the bgs vnp_ptcpnt_addrs_service is not healthy' do
          allow_any_instance_of(ClaimsApi::VnpPtcpntAddrsService).to receive(:vnp_ptcpnt_addrs_create)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp-ptcpnt-addrs-service']['success']).to eq(false)
        end

        # 'bgs_service/vnp_ptcpnt_phone_service'
        it 'returns the correct status when the bgs vnp_ptcpnt_phone_service is not healthy' do
          allow_any_instance_of(ClaimsApi::VnpPtcpntPhoneService).to receive(:vnp_ptcpnt_phone_create)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp-ptcpnt-phone-service']['success']).to eq(false)
        end

        # 'bgs_service/vnp_ptcpnt_service'
        it 'returns the correct status when the bgs vnp_ptcpnt_service is not healthy' do
          allow_any_instance_of(ClaimsApi::VnpPtcpntService).to receive(:vnp_ptcpnt_create)
            .and_return(Struct.new(:healthy?).new(false))
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp-ptcpnt-service']['success']).to eq(false)
        end
      end
    end
  end
end
