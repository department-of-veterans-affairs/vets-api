# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_documents/service'

RSpec.shared_examples 'claims and appeals overview' do |lighthouse_flag|
  include CommitteeHelper

  let(:good_claims_response_vcr_path) do
    lighthouse_flag ? 'mobile/lighthouse_claims/index/200_response' : 'mobile/claims/claims'
  end

  let(:claim_count) do
    lighthouse_flag ? 6 : 143
  end

  let(:error_claims_response_vcr_path) do
    lighthouse_flag ? 'mobile/lighthouse_claims/index/404_response' : 'mobile/claims/claims_with_errors'
  end

  before do
    Flipper.enable(:mobile_claims_log_decision_letter_sent)

    if lighthouse_flag
      token = 'abcdefghijklmnop'
      allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
      Flipper.enable(:mobile_lighthouse_claims)
    else
      Flipper.disable(:mobile_lighthouse_claims)
    end
  end

  after { Flipper.disable(:mobile_claims_log_decision_letter_sent) }

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
            if lighthouse_flag
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
            else
              expect(parsed_response_contents.length).to eq(60)
              expect(response.parsed_body.dig('meta', 'pagination', 'totalPages')).to eq(3)
              open_claim = parsed_response_contents.select { |entry| entry['id'] == '600114693' }[0]
              closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600106271' }[0]
              decision_letter_sent_claim = parsed_response_contents.select { |entry| entry['id'] == '600096536' }[0]
              expect(open_claim.dig('attributes', 'updatedAt')).to eq('2017-09-28')
              expect(open_claim.dig('attributes', 'phase')).to be_nil
              expect(open_claim.dig('attributes', 'documentsNeeded')).to be_nil
              expect(open_claim.dig('attributes', 'developmentLetterSent')).to be_nil
              expect(open_claim.dig('attributes', 'claimTypeCode')).to be_nil
              expect(closed_claim.dig('attributes', 'updatedAt')).to eq('2017-09-20')
            end

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
            claims_error_message = if lighthouse_flag
                                     'Resource not found'
                                   else
                                     "Please define your custom text for this error in \
claims-webparts/ErrorCodeMessages.properties. [Unique ID: 1522946240935]"
                                   end
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
            if lighthouse_flag
              open_claim = parsed_response_contents.select { |entry| entry['id'] == '600383363' }[0]
              closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600229968' }[0]
            else
              open_claim = parsed_response_contents.select { |entry| entry['id'] == '600114693' }[0]
              closed_claim = parsed_response_contents.select { |entry| entry['id'] == '600106271' }[0]
            end
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
            claims_error_message = if lighthouse_flag
                                     'Resource not found'
                                   else
                                     "Please define your custom text for this error in \
claims-webparts/ErrorCodeMessages.properties. [Unique ID: 1522946240935]"
                                   end
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
        expected_count = lighthouse_flag ? 7 : 6
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
        expected_count = lighthouse_flag ? 12 : 11
        active_claims_count = response.parsed_body['data'].count do |item|
          item['attributes']['completed'] == false
        end
        expect(active_claims_count).to eq(expected_count)
        expect(response.parsed_body.dig('meta', 'activeClaimsCount')).to eq(expected_count)
      end
    end

    context 'when an internal error occurs getting claims' do
      it 'includes appeals but has error details in the meta object for claims' do
        if lighthouse_flag
          allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_raise(NoMethodError)
        else
          allow_any_instance_of(User).to receive(:loa).and_raise(NoMethodError)
        end
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

      it 'retrieves the cached claims amd appeals rather than hitting the service' do
        path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'claims_and_appeals.json')
        data = Mobile::V0::Adapters::ClaimsOverview.new.parse(JSON.parse(File.read(path)))
        Mobile::V0::ClaimOverview.set_cached(user, data)

        get('/mobile/v0/claims-and-appeals-overview', headers: sis_headers, params:)
        assert_schema_conform(200)
        parsed_response_contents = response.parsed_body['data']
        open_claim = parsed_response_contents.select { |entry| entry['id'] == '600114693' }[0]
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
            evss_id = lighthouse_flag ? 600_383_363 : 600_114_693
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
  end

  describe 'GET /v0/claim-letter/documents' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      let!(:response_body) do
        {
          data: {
            documents: [
              {
                docTypeId: '702',
                subject: 'foo',
                documentUuid: '73CD7B28-F695-4337-BBC1-2443A913ACF6',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'Disability Benefits Questionnaire (DBQ) - Veteran Provided',
                trackedItemId: 600_000_001,
                uploadedDateTime: '2024-09-13T17:51:56Z'
              }, {
                docTypeId: '45',
                subject: 'bar ',
                documentUuid: 'EF7BF420-7E49-4FA9-B14C-CE5F6225F615',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'Military Personnel Record',
                trackedItemId: 600_000_002,
                uploadedDateTime: '2024-09-13T178:32:24Z'
              }
            ]
          }
        }
      end

      let!(:claim_letter_doc_response) do
        { 'data' => [{ 'id' => '{73CD7B28-F695-4337-BBC1-2443A913ACF6}', 'type' => 'claim_letter_document',
                       'attributes' => { 'docType' => '702',
                                         'typeDescription' =>
                                           'Disability Benefits Questionnaire (DBQ) - Veteran Provided',
                                         'receivedAt' => '2024-09-13T17:51:56Z' } },
                     { 'id' => '{EF7BF420-7E49-4FA9-B14C-CE5F6225F615}', 'type' => 'claim_letter_document',
                       'attributes' => { 'docType' => '45',
                                         'typeDescription' => 'Military Personnel Record',
                                         'receivedAt' => '2024-09-13T178:32:24Z' } }] }
      end

      before do
        benefits_document_service_double = double
        expect(BenefitsDocuments::Service).to receive(:new).and_return(benefits_document_service_double)
        expect(benefits_document_service_double).to receive(:claim_letters_search).and_return(
          Faraday::Response.new(
            status: 200, body: response_body.as_json
          )
        )
      end

      it 'and a result that matches our schema is successfully returned with the 200 status' do
        get '/mobile/v0/claim-letter/documents', headers: sis_headers
        assert_schema_conform(200)
        expect(response.parsed_body).to eq(claim_letter_doc_response)
      end
    end

    context 'with an error from upstream' do
      let(:bad_request_error) do
        Faraday::BadRequestError.new(
          status: 400,
          headers: {
            'content-type' => 'application/json'
          },
          body: {
            'errors' => [{
              'status' => 400,
              'title' => 'Invalid field value',
              'detail' => 'Code must match \"^[A-Z]{2}$\"'
            }]
          }
        )
      end

      before do
        allow_any_instance_of(BenefitsDocuments::Configuration)
          .to receive(:claim_letters_search).and_raise(bad_request_error)
      end

      it 'returns expected error' do
        get '/mobile/v0/claim-letter/documents', headers: sis_headers

        assert_schema_conform(400)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Invalid field value',
                                                            'detail' => 'Code must match \"^[A-Z]{2}$\"',
                                                            'code' => '400',
                                                            'status' => '400' }] })
      end
    end
  end

  describe 'POST /v0/claim-letter/documents/:document_id/download' do
    let!(:user) { sis_user }

    context 'with working upstream service' do
      let(:document_uuid) { '93631483-E9F9-44AA-BB55-3552376400D8' }
      let(:content) { File.read('spec/fixtures/files/error_message.txt') }

      before do
        benefits_document_service_double = double
        expect(BenefitsDocuments::Service).to receive(:new).and_return(benefits_document_service_double)
        expect(benefits_document_service_double)
          .to receive(:claim_letter_download).with(
            document_uuid:,
            participant_id: user.participant_id
          ).and_return(
            Faraday::Response.new(
              status: 200, body: content
            )
          )
      end

      it 'returns expected document' do
        post "/mobile/v0/claim-letter/documents/#{CGI.escape("{#{document_uuid}}")}/download",
             params: { file_name: 'test' },
             headers: sis_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(content)
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=\"test\"; filename*=UTF-8''test")
        expect(response.headers['Content-Type']).to eq('application/pdf')
      end
    end

    context 'with an error from upstream' do
      let(:bad_request_error) do
        Faraday::BadRequestError.new(
          status: 400,
          headers: {
            'content-type' => 'application/json'
          },
          body: {
            'errors' => [{
              'status' => 400,
              'title' => 'Invalid field value',
              'detail' => 'Code must match \"^[A-Z]{2}$\"'
            }]
          }
        )
      end

      before do
        allow_any_instance_of(BenefitsDocuments::Configuration)
          .to receive(:claim_letter_download).and_raise(bad_request_error)
      end

      it 'returns expected error' do
        post '/mobile/v0/claim-letter/documents/123/download', params: { file_name: 'test' }, headers: sis_headers

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq({ 'errors' => [{ 'title' => 'Invalid field value',
                                                            'detail' => 'Code must match \"^[A-Z]{2}$\"',
                                                            'code' => '400',
                                                            'status' => '400' }] })
      end
    end
  end
end

RSpec.describe 'Mobile::V0::ClaimsAndAppeals', type: :request do
  include JsonSchemaMatchers

  it_behaves_like 'claims and appeals overview', false
  it_behaves_like 'claims and appeals overview', true
end
