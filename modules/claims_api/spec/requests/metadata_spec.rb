# frozen_string_literal: true

require 'rails_helper'
require 'bgs/services'
require 'mpi/service'
require 'bgs_service/local_bgs'

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
          expect(parsed_response['default']['success']).to be(true)
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
        before do
          allow(IdentitySettings.mvi).to receive(:mock).and_return(false)
        end

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
          expect(result['mpi']['success']).to be(false)
        end

        it 'returns the correct status when the benefit-claim-service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['benefit_claim_service']['success']).to be(false)
        end

        it 'returns the correct status when the claimant service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['claimant_web_service']['success']).to be(false)
        end

        it 'returns the correct status when the claim_management_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['claim_management_service']['success']).to be(false)
        end

        it 'returns the correct status when the contention_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['contention_service']['success']).to be(false)
        end

        it 'returns the correct status when the corporate_update_web_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['corporate_update_web_service']['success']).to be(false)
        end

        it 'returns the correct status when the e-benefits-bnft-claim-status-web-service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['e_benefits_bnft_claim_status_web_service']['success']).to be(false)
        end

        it 'returns the correct status when the intenttofile is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['intent_to_file_web_service']['success']).to be(false)
        end

        it 'returns the correct status when bgs org service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['org_web_service']['success']).to be(false)
        end

        it 'returns the correct status when the person_web_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['person_web_service']['success']).to be(false)
        end

        it 'returns the correct status when the bgs standard_data_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['standard_data_service']['success']).to be(false)
        end

        it 'returns the correct status when the bgs standard_data_web_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['standard_data_web_service']['success']).to be(false)
        end

        it 'returns the correct status when the bgs trackeditem is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['tracked_item_service']['success']).to be(false)
        end

        it 'returns the correct status when the manage rep service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vdc_manage_representative_service']['success']).to be(false)
        end

        it 'returns the correct status when the vet rep service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vdc_veteran_representative_service']['success']).to be(false)
        end

        it 'returns the correct status when the bgs vet_record service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vet_record_web_service']['success']).to be(false)
        end

        # 'bgs_service/vnp_atchms_service'
        it 'returns the correct status when the bgs vnp_atchms_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp_atchms_service']['success']).to be(false)
        end

        # 'bgs_service/vnp_person_service'
        it 'returns the correct status when the bgs vnp_person_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp_person_service']['success']).to be(false)
        end

        # 'bgs_service/vnp_proc_form_service'
        it 'returns the correct status when the bgs vnp_proc_form_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp_proc_form_service']['success']).to be(false)
        end

        # 'bgs_service/vnp_proc_service_v2'
        it 'returns the correct status when the bgs vnp_proc_service_v2 is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp_proc_service_v2']['success']).to be(false)
        end

        # 'bgs_service/vnp_ptcpnt_addrs_service'
        it 'returns the correct status when the bgs vnp_ptcpnt_addrs_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp_ptcpnt_addrs_service']['success']).to be(false)
        end

        # 'bgs_service/vnp_ptcpnt_phone_service'
        it 'returns the correct status when the bgs vnp_ptcpnt_phone_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp_ptcpnt_phone_service']['success']).to be(false)
        end

        # 'bgs_service/vnp_ptcpnt_service'
        it 'returns the correct status when the bgs vnp_ptcpnt_service is not healthy' do
          get "/services/claims/#{version}/upstream_healthcheck"
          result = JSON.parse(response.body)
          expect(result['vnp_ptcpnt_service']['success']).to be(false)
        end
      end
    end
  end
end
