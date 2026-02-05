# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service'

RSpec.describe 'Mobile::V0::ClaimsAndAppeals', type: :request do
  include CommitteeHelper
  # include JsonSchemaMatchers

  let(:good_claims_response_vcr_path) { 'mobile/lighthouse_claims/index/200_response' }
  let(:claim_count) { 6 }
  let(:error_claims_response_vcr_path) { 'mobile/lighthouse_claims/index/404_response' }

  before do
    allow(Flipper).to receive(:enabled?).with(:mobile_claims_log_decision_letter_sent).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(false)
    token = 'abcdefghijklmnop'
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#index is polled an unauthorized user' do
    it 'and not user returns a 401 status' do
      get '/mobile/v0/claims-and-appeals-overview'
      assert_schema_conform(401)
    end
  end

  describe 'GET /v0/claims-and-appeals-overview' do
    let!(:user) { sis_user(icn: '1008596379V859838') }
    let(:params) { { useCache: false, page: { size: 60 } } }

    describe '#index (all user claims) is polled' do
      it 'and a result that matches our schema is successfully returned with the 200 status' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(200)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            expect(parsed_response_contents.length).to eq(11)
            expect(response.parsed_body.dig('meta', 'pagination', 'totalPages')).to eq(1)
            open_claim = parsed_response_contents.select { |entry| entry['id'] == '600383363' }[0]
            closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600229968' }[0]
            decision_letter_sent_claim = parsed_response_contents.select { |entry| entry['id'] == '600323434' }[0]
            nil_dates_claim = parsed_response_contents.last
            expect(open_claim.dig('attributes', 'updatedAt')).to eq('2022-09-30')
            expect(open_claim.dig('attributes', 'phase')).to eq(4)
            expect(open_claim.dig('attributes', 'documentsNeeded')).to be(false)
            expect(open_claim.dig('attributes', 'developmentLetterSent')).to be(true)
            expect(open_claim.dig('attributes', 'claimTypeCode')).to eq('400PREDSCHRG')
            expect(closed_claim.dig('attributes', 'updatedAt')).to eq('2021-03-22')
            expect(closed_claim.dig('attributes', 'updatedAt')).to eq('2021-03-22')
            expect(nil_dates_claim.dig('attributes', 'updatedAt')).to be_nil
            expect(nil_dates_claim.dig('attributes', 'dateFiled')).to be_nil

            open_appeal = parsed_response_contents.select { |entry| entry['id'] == '3294289' }[0]
            expect(open_claim.dig('attributes', 'completed')).to be(false)
            expect(closed_claim.dig('attributes', 'completed')).to be(true)
            expect(open_appeal.dig('attributes', 'completed')).to be(false)
            expect(open_claim['type']).to eq('claim')
            expect(closed_claim['type']).to eq('claim')
            expect(open_appeal['type']).to eq('appeal')
            expect(open_appeal.dig('attributes', 'updatedAt')).to eq('2018-01-16')
            expect(open_appeal.dig('attributes', 'displayTitle')).to eq('disability compensation appeal')
            expect(open_claim.dig('attributes', 'decisionLetterSent')).to be(false)
            expect(closed_claim.dig('attributes', 'decisionLetterSent')).to be(false)
            expect(open_appeal.dig('attributes', 'decisionLetterSent')).to be(false)
            expect(decision_letter_sent_claim.dig('attributes', 'decisionLetterSent')).to be(true)
          end
        end
      end

      it 'and invalid headers return a 401 status' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get '/mobile/v0/claims-and-appeals-overview'
            assert_schema_conform(401)
          end
        end
      end
    end

    describe '#index (all user claims) is polled with additional pagination params' do
      let(:params) do
        { useCache: false,
          startDate: '2017-05-01T07:00:00.000Z',
          page: { number: 2, size: 2 } }
      end

      it 'and the results are for page 2 of a 12 item pages which only has 10 entries' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(200)

            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            expect(parsed_response_contents.length).to eq(2)
          end
        end
      end
    end

    describe '#index (all user claims) is polled requesting only closed claims' do
      let(:params) do
        { useCache: false,
          startDate: '2017-05-01T07:00:00.000Z',
          showCompleted: true }
      end

      it 'and the results contain only closed records' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(200)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            parsed_response_contents.each do |entry|
              expect(entry.dig('attributes', 'completed')).to be(true)
            end
          end
        end
      end
    end

    describe '#index (all user claims) is polled requesting only open claims' do
      let(:params) do
        { useCache: false,
          startDate: '2017-05-01T07:00:00.000Z',
          showCompleted: false }
      end

      it 'and the results contain only open records' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(200)
            # check a couple entries to make sure the data is correct
            parsed_response_contents = response.parsed_body['data']
            parsed_response_contents.each do |entry|
              expect(entry.dig('attributes', 'completed')).to be(false)
            end
          end
        end
      end
    end

    describe '#index is polled' do
      let(:params) { { useCache: false } }

      it 'and claims service fails, but appeals succeeds' do
        VCR.use_cassette(error_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)
            parsed_response_contents = response.parsed_body['data']
            expect(parsed_response_contents[0]['type']).to eq('appeal')
            expect(parsed_response_contents.last['type']).to eq('appeal')
            claims_error_message = 'Resource not found'
            expect(response.parsed_body.dig('meta', 'errors')).to eq(
              [{ 'service' => 'claims', 'errorDetails' => claims_error_message }]
            )
            open_appeal = parsed_response_contents.select { |entry| entry['id'] == '3294289' }[0]
            closed_appeal = parsed_response_contents.select { |entry| entry['id'] == '2348605' }[0]
            expect(open_appeal.dig('attributes', 'completed')).to be(false)
            expect(closed_appeal.dig('attributes', 'completed')).to be(true)
            expect(open_appeal['type']).to eq('appeal')
            expect(closed_appeal['type']).to eq('appeal')
            expect(open_appeal.dig('attributes', 'displayTitle')).to eq('disability compensation appeal')
            expect(closed_appeal.dig('attributes', 'displayTitle')).to eq('appeal')
          end
        end
      end

      it 'and appeals service fails, but claims succeeds' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/server_error') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)
            parsed_response_contents = response.parsed_body['data']
            expect(parsed_response_contents[0]['type']).to eq('claim')
            expect(parsed_response_contents.last['type']).to eq('claim')
            expect(response.parsed_body.dig('meta', 'errors')).to eq(
              [{ 'service' => 'appeals', 'errorDetails' => 'Received a 500 response from the upstream server' }]
            )
            open_claim = parsed_response_contents.select { |entry| entry['id'] == '600383363' }[0]
            closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600229968' }[0]

            expect(open_claim.dig('attributes', 'completed')).to be(false)
            expect(closed_claim.dig('attributes', 'completed')).to be(true)
            expect(open_claim['type']).to eq('claim')
            expect(closed_claim['type']).to eq('claim')
          end
        end
      end

      it 'caches response if both claims and appeals succeeds' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            expect(Mobile::V0::ClaimOverview.get_cached(user)).not_to be_nil
          end
        end
      end

      it 'both fail in upstream service' do
        VCR.use_cassette(error_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/server_error') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(502)
            claims_error_message = 'Resource not found'
            expect(response.parsed_body.dig('meta', 'errors')).to eq(
              [{ 'service' => 'claims', 'errorDetails' => claims_error_message },
               { 'service' => 'appeals', 'errorDetails' => 'Received a 500 response from the upstream server' }]
            )
          end
        end
      end

      it 'does not cache the response if appeals fails and claims succeeds' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/server_error') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          end
        end
      end

      it 'does not cache the response if claims fails and appeals succeeds' do
        VCR.use_cassette(error_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          end
        end
      end
    end

    describe 'active_claims_count' do
      it 'aggregates all incomplete claims and appeals into active_claims_count' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
          end
        end

        assert_schema_conform(200)
        expected_count = 7
        active_claims_count = response.parsed_body['data'].count do |item|
          item['attributes']['completed'] == false
        end
        expect(active_claims_count).to eq(expected_count)
        expect(response.parsed_body.dig('meta', 'activeClaimsCount')).to eq(expected_count)
      end

      it 'ignores pagination so that active claim count can be above 10' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/pagination_required_appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
          end
        end

        assert_schema_conform(200)
        expected_count = 12
        active_claims_count = response.parsed_body['data'].count do |item|
          item['attributes']['completed'] == false
        end
        expect(active_claims_count).to eq(expected_count)
        expect(response.parsed_body.dig('meta', 'activeClaimsCount')).to eq(expected_count)
      end
    end

    context 'when an internal error occurs getting claims' do
      it 'includes appeals but has error details in the meta object for claims' do
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_raise(NoMethodError)

        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            expect(response.parsed_body['data'].size).to eq(
              5
            )
            expect(response.parsed_body.dig('meta', 'errors').first).to eq(
              { 'service' => 'claims',
                'errorDetails' => 'NoMethodError' }
            )
          end
        end
      end
    end

    context 'when there are cached claims and appeals' do
      let(:params) { { useCache: true, page: { size: 999 } } }

      it 'retrieves the cached claims and appeals rather than hitting the service' do
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'claims_and_appeals.json')
        data = Mobile::V0::Adapters::ClaimsOverview.new.parse(JSON.parse(File.read(path)))
        Mobile::V0::ClaimOverview.set_cached(user, data)

        get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
        assert_schema_conform(200)
        parsed_response_contents = response.parsed_body['data']
        open_claim = parsed_response_contents.select { |entry| entry['id'] == '600561746' }[0]
        expect(open_claim.dig('attributes', 'completed')).to be(false)
        expect(open_claim['type']).to eq('claim')
      end

      context 'when user is only authorized to access claims, not appeals' do
        before { allow_any_instance_of(User).to receive(:loa3?).and_return(nil) }

        context 'claims service succeed' do
          it 'uses cached claims' do
            VCR.use_cassette(good_claims_response_vcr_path) do
              get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            end

            assert_schema_conform(207)
            data = response.parsed_body['data']
            expect(data.dig(0, 'type')).to eq('claim')
            expect(data.count).to eq(claim_count)

            error = response.parsed_body['meta'].dig('errors', 0, 'errorDetails')
            expect(error).to eq('Forbidden: User is not authorized for appeals')

            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            expect(response).to have_http_status(:multi_status)
            expect(response.parsed_body['data'].count).to eq(claim_count)
            expect(response.parsed_body.dig('meta', 'errors', 0,
                                            'errorDetails')).to eq('Forbidden: User is not authorized for appeals')
          end
        end

        context 'claims service fails' do
          it 'returns error and does not cache' do
            VCR.use_cassette(error_claims_response_vcr_path) do
              get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
              expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
              assert_schema_conform(502)
            end
          end
        end
      end

      context 'when user is only authorized to access appeals, not claims' do
        before { allow_any_instance_of(User).to receive(:participant_id).and_return(nil) }

        context 'appeals service succeed' do
          it 'appeals service succeed and caches appeals' do
            VCR.use_cassette('mobile/appeals/appeals') do
              get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            end

            assert_schema_conform(207)

            data = response.parsed_body['data']
            expect(data.dig(0, 'type')).to eq('appeal')
            expect(data.count).to eq(5)

            error = response.parsed_body['meta'].dig('errors', 0, 'errorDetails')
            expect(error).to eq('Forbidden: User is not authorized for claims')

            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)
            expect(response.parsed_body['data'].count).to eq(5)
            expect(response.parsed_body.dig('meta', 'errors', 0,
                                            'errorDetails')).to eq('Forbidden: User is not authorized for claims')
          end
        end

        context 'appeals service fails' do
          it 'returns error and does not cache' do
            VCR.use_cassette('mobile/appeals/server_error') do
              get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
              expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
              assert_schema_conform(502)
            end
          end
        end
      end
    end

    context 'when user is only authorized to access claims, not appeals' do
      before { allow_any_instance_of(User).to receive(:loa3?).and_return(nil) }

      it 'and claims service succeed' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)
          end
        end
      end

      it 'and claims service fails' do
        VCR.use_cassette(error_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(502)
          end
        end
      end
    end

    context 'when user is only authorized to access appeals, not claims' do
      let!(:user) do
        sis_user(icn: '1008596379V859838', participant_id: nil)
      end

      it 'and appeals service succeed' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)
          end
        end
      end

      it 'and appeals service fails' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/server_error') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(502)
          end
        end
      end
    end

    context 'when user is not authorized to access neither claims or appeals' do
      let!(:user) do
        sis_user(:api_auth, :loa1, icn: '1008596379V859838', participant_id: nil)
      end

      it 'returns 403 status' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(403)
          end
        end
      end
    end

    describe 'EVSSClaim count' do
      it 'creates record if it does not exist' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            expect do
              get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            end.to change(EVSSClaim, :count)
          end
        end
      end

      it 'updates record if it does exist' do
        VCR.use_cassette(good_claims_response_vcr_path) do
          VCR.use_cassette('mobile/appeals/appeals') do
            evss_id = 600_383_363
            claim = EVSSClaim.create(user_uuid: sis_user.uuid,
                                     user_account: sis_user.user_account,
                                     evss_id:,
                                     created_at: 1.week.ago,
                                     updated_at: 1.week.ago,
                                     data: {})
            expect do
              get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
              claim.reload
            end.to change(claim, :updated_at)
          end
        end
      end
    end

    describe 'multi-provider authorization edge cases' do
      before do
        allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider_mobile, anything).and_return(true)
        allow(Flipper).to receive(:enabled?).with('benefits_claims_lighthouse_provider', anything).and_return(true)
      end

      context 'when user is only authorized to access appeals, not claims' do
        let!(:user) do
          sis_user(icn: '1008596379V859838', participant_id: nil)
        end

        it 'returns appeals with authorization error for claims' do
          VCR.use_cassette('mobile/appeals/appeals') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)

            data = response.parsed_body['data']
            expect(data.dig(0, 'type')).to eq('appeal')
            expect(data.count).to eq(5)

            error = response.parsed_body['meta'].dig('errors', 0, 'errorDetails')
            expect(error).to eq('Forbidden: User is not authorized for claims')
          end
        end

        it 'includes authorization error even when data is cached' do
          VCR.use_cassette('mobile/appeals/appeals') do
            # First request - populate cache
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)

            # Second request - use cache and should still include authorization error
            cached_params = params.merge(useCache: true)
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params: cached_params)
            assert_schema_conform(207)

            expect(response.parsed_body['data'].count).to eq(5)
            expect(response.parsed_body.dig('meta', 'errors', 0,
                                            'errorDetails')).to eq('Forbidden: User is not authorized for claims')
          end
        end

        it 'returns 502 when appeals service fails' do
          VCR.use_cassette('mobile/appeals/server_error') do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
            assert_schema_conform(502)
          end
        end
      end

      context 'when user is only authorized to access claims, not appeals' do
        before do
          allow_any_instance_of(User).to receive(:loa3?).and_return(nil)
          allow(Flipper).to receive(:enabled?).with('benefits_claims_lighthouse_provider', anything).and_return(true)
        end

        it 'returns claims with authorization error for appeals' do
          VCR.use_cassette(good_claims_response_vcr_path) do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)

            data = response.parsed_body['data']
            expect(data.dig(0, 'type')).to eq('claim')
            expect(data.count).to eq(6)

            error = response.parsed_body['meta'].dig('errors', 0, 'errorDetails')
            expect(error).to eq('Forbidden: User is not authorized for appeals')
          end
        end

        it 'includes authorization error even when data is cached' do
          VCR.use_cassette(good_claims_response_vcr_path) do
            # First request - populate cache
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
            assert_schema_conform(207)

            # Second request - use cache and should still include authorization error
            cached_params = params.merge(useCache: true)
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params: cached_params)
            assert_schema_conform(207)

            expect(response.parsed_body['data'].count).to eq(6)
            expect(response.parsed_body.dig('meta', 'errors', 0,
                                            'errorDetails')).to eq('Forbidden: User is not authorized for appeals')
          end
        end

        it 'returns error when claims service fails' do
          allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_raise(StandardError)

          VCR.use_cassette(good_claims_response_vcr_path) do
            get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)

            # Should have authorization error for appeals plus provider error for claims
            errors = response.parsed_body['meta']['errors']
            expect(errors).to be_present
            expect(errors.map { |e| e['errorDetails'] }).to include(
              'Forbidden: User is not authorized for appeals',
              'Provider temporarily unavailable'
            )
          end
        end
      end

      context 'when user is not authorized to access neither claims nor appeals' do
        let!(:user) do
          sis_user(:api_auth, :loa1, icn: '1008596379V859838', participant_id: nil)
        end

        it 'returns 403 status' do
          VCR.use_cassette(good_claims_response_vcr_path) do
            VCR.use_cassette('mobile/appeals/appeals') do
              get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
              assert_schema_conform(403)
            end
          end
        end
      end
    end
  end
end
