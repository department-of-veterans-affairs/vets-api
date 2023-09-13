# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/configuration'

RSpec.describe 'VirtualAgentClaims', type: :request do
  let(:user) { create(:user, :loa3) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }

  before do
    Flipper.disable(:virtual_agent_lighthouse_claims)

    @mock_cxdw_reporting_service = instance_double(V0::VirtualAgent::ReportToCxdw)
    allow(@mock_cxdw_reporting_service).to receive(:report_to_cxdw)

    allow(V0::VirtualAgent::ReportToCxdw)
      .to receive(:new)
      .and_return(@mock_cxdw_reporting_service)
  end

  describe 'GET /v0/virtual_agent/claim' do
    let!(:claim) do
      FactoryBot.create(:evss_claim, id: 11, evss_id: 600_118_854,
                                     user_uuid: user.uuid)
      FactoryBot.create(:evss_claim, id: 22, evss_id: 600_118_855,
                                     user_uuid: user.uuid)
      FactoryBot.create(:evss_claim, id: 33, evss_id: 600_118_851,
                                     user_uuid: user.uuid)
    end

    it 'returns information on multiple open compensation claims in descending chronological order by updated date' do
      sign_in_as(user)

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims_multiple_open_compensation_claims') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end
      VCR.use_cassette('evss/claims/claim_with_docs1') do
        EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, 11)
      end
      VCR.use_cassette('evss/claims/claim_with_docs2') do
        EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, 22)
      end
      VCR.use_cassette('evss/claims/claim_with_docs3') do
        EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, 33)
      end

      get '/v0/virtual_agent/claim'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to be_kind_of(Array)

      expect(JSON.parse(response.body)['data'].size).to equal(3)
      expect(JSON.parse(response.body)['data']).to eq([{
                                                        'claim_type' => 'Compensation',
                                                        'claim_status' => 'UNDER REVIEW',
                                                        'filing_date' => '02/08/2017',
                                                        'evss_id' => '600118854',
                                                        'updated_date' => '03/10/2018'
                                                      },
                                                       {
                                                         'claim_type' => 'Compensation',
                                                         'claim_status' => 'UNDER REVIEW',
                                                         'filing_date' => '01/08/2018',
                                                         'evss_id' => '600118855',
                                                         'updated_date' => '01/10/2018'
                                                       },
                                                       {
                                                         'claim_type' => 'Compensation',
                                                         'claim_status' => 'UNDER REVIEW',
                                                         'filing_date' => '12/08/2017',
                                                         'evss_id' => '600118851',
                                                         'updated_date' => '12/08/2017'
                                                       }])
    end

    describe 'for a single claim' do
      let!(:claim) do
        FactoryBot.create(:evss_claim, id: 3, evss_id: 600_118_851,
                                       user_uuid: user.uuid)
      end

      it 'returns information on single open compensation claim' do
        sign_in_as(user)

        get '/v0/virtual_agent/claim'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
        expect(JSON.parse(response.body)['data']).to eq nil

        # run job
        VCR.use_cassette('evss/claims/claims_with_single_open_compensation_claim') do
          EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
        end
        VCR.use_cassette('evss/claims/claim_with_docs1') do
          EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, 3)
        end

        get '/v0/virtual_agent/claim'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
        expect(JSON.parse(response.body)['data']).to be_kind_of(Array)
        expect(JSON.parse(response.body)['data'].size).to equal(1)
        expect(JSON.parse(response.body)['data']).to include({
                                                               'claim_type' => 'Compensation',
                                                               'claim_status' => 'UNDER REVIEW',
                                                               'filing_date' => '12/08/2017',
                                                               'evss_id' => '600118851',
                                                               'updated_date' => '12/08/2017'
                                                             })
      end

      it 'returns claim information without rep when claim details service times out' do
        sign_in_as(user)

        get '/v0/virtual_agent/claim'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
        expect(JSON.parse(response.body)['data']).to eq nil

        # run job
        VCR.use_cassette('evss/claims/claims_with_single_open_compensation_claim') do
          EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
        end

        get '/v0/virtual_agent/claim'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
        expect(JSON.parse(response.body)['data']).to be_kind_of(Array)
        expect(JSON.parse(response.body)['data'].size).to equal(1)
        expect(JSON.parse(response.body)['data']).to include({
                                                               'claim_type' => 'Compensation',
                                                               'claim_status' => 'UNDER REVIEW',
                                                               'filing_date' => '12/08/2017',
                                                               'evss_id' => '600118851',
                                                               'updated_date' => '12/08/2017'
                                                             })
      end
    end

    it 'returns empty array when no open claims are found' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims_trimmed_down') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to be_kind_of(Array)
      expect(JSON.parse(response.body)['data'].size).to equal(0)
    end

    it 'returns empty array when there are only closed compensation claims' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims_historical_compensation') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to be_kind_of(Array)
      expect(JSON.parse(response.body)['data'].size).to equal(0)
    end

    describe 'for a user who has non-compensation and compensation claims' do
      let!(:claim) do
        FactoryBot.create(:evss_claim, id: 3, evss_id: 600_114_693,
                                       user_uuid: user.uuid)
      end

      it 'returns information when there is a more recent non-compensation open claim' do
        sign_in_as(user)
        get '/v0/virtual_agent/claim'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
        expect(JSON.parse(response.body)['data']).to eq nil

        # run job
        VCR.use_cassette('evss/claims/claims_most_recent_dependent') do
          EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
        end
        VCR.use_cassette('evss/claims/claim_with_docs4') do
          EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, 3)
        end

        get '/v0/virtual_agent/claim'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
        expect(JSON.parse(response.body)['data']).to include({
                                                               'claim_type' => 'Compensation',
                                                               'claim_status' => 'CLAIM RECEIVED',
                                                               'filing_date' => '09/28/2017',
                                                               'evss_id' => '600114693',
                                                               'updated_date' => '09/28/2017'
                                                             })
      end
    end
  end

  describe 'GET /v0/virtual_agent/claim/{EVSS_ID}' do
    let!(:claim) do
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_117_255,
                                     user_uuid: user.uuid)
    end

    it 'returns claims details of a specific claim' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim/600117255'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq({ 'va_representative' => 'AMERICAN LEGION' })
      VCR.use_cassette('evss/claims/claim_with_docs') do
        EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, claim.id)
      end
      get '/v0/virtual_agent/claim/600117255'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to eq({ 'va_representative' => 'VENKATA KOMMOJU' })
    end
  end

  describe 'controller logs exceptions to Sentry' do
    it 'returns service unavailable when controller reports a blah exception' do
      sign_in_as(user)

      VCR.use_cassette('evss/claims/claims_with_errors') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      rescue
        get '/v0/virtual_agent/claim'

        # if :service_unavailable is the status, Sentry logging was called
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  describe 'Cxdw reporting service' do
    it 'runs with user info when claims retrieval is successful' do
      sign_in_as(user)

      VCR.use_cassette('evss/claims/claims_multiple_open_compensation_claims') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)

        get '/v0/virtual_agent/claim?conversation_id=123'

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
        expect(@mock_cxdw_reporting_service).to have_received(:report_to_cxdw).with(user.icn, '123')
      end
    end

    it 'runs with user info when claims retrieval fails' do
      sign_in_as(user)

      VCR.use_cassette('evss/claims/claims_with_errors') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      rescue

        get '/v0/virtual_agent/claim?conversation_id=123'

        expect(response).to have_http_status(:service_unavailable)
        expect(@mock_cxdw_reporting_service).to have_received(:report_to_cxdw).with(user.icn, '123')
      end
    end

    context 'when reporting fails' do
      it 'returns claims when claims retrieval successful' do
        sign_in_as(user)
        error = StandardError.new
        error_message = { 'context' => 'An error occurred while attempting to report the claim(s).' }
        allow(@mock_cxdw_reporting_service).to receive(:report_to_cxdw).and_raise(error)

        VCR.use_cassette('evss/claims/claims_multiple_open_compensation_claims') do
          EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)

          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(error, error_message)
          get '/v0/virtual_agent/claim?conversation_id=123'
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
          expect(@mock_cxdw_reporting_service).to have_received(:report_to_cxdw).with(user.icn, '123')
        end
      end

      it 'returns service unavailable when claims retrieval fails' do
        sign_in_as(user)
        allow(@mock_cxdw_reporting_service).to receive(:report_to_cxdw).and_raise('message')

        VCR.use_cassette('evss/claims/claims_with_errors') do
          EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
          error = StandardError.new
          error_message = { 'context' => 'An error occurred while attempting to retrieve the claim(s).' }
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(error, error_message)
        rescue

          get '/v0/virtual_agent/claim?conversation_id=123'

          expect(response).to have_http_status(:service_unavailable)
          expect(@mock_cxdw_reporting_service).to have_received(:report_to_cxdw).with(user.icn, '123')
        end
      end
    end
  end
end
