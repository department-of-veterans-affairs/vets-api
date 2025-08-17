# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/direct_deposit/configuration'
require 'support/bb_client_helpers'
require 'support/pagerduty/services/spec_setup'
require 'support/stub_debt_letters'
require 'support/medical_copays/stub_medical_copays'
require 'support/stub_efolder_documents'
require_relative '../../../modules/debts_api/spec/support/stub_financial_status_report'
require 'bgs/service'
require 'sign_in/logingov/service'
require 'hca/enrollment_eligibility/constants'
require 'form1010_ezr/service'
require 'lighthouse/facilities/v1/client'
require 'debts_api/v0/digital_dispute_submission_service'

# rubocop:disable Rspec/MultipleDescribes
RSpec.describe 'the v0 API documentation (Part 7)', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
    end

    describe 'claim status tool' do
      let!(:claim) do
        create(:evss_claim, id: 1, evss_id: 189_625,
                            user_uuid: mhv_user.uuid, data: {})
      end

      it 'uploads a document to support a claim' do
        expect(subject).to validate(
          :post,
          '/v0/evss_claims/{evss_claim_id}/documents',
          202,
          headers.merge('_data' => { file: fixture_file_upload('doctors-note.pdf', 'application/pdf'),
                                     tracked_item_id: 33,
                                     document_type: 'L023' }, 'evss_claim_id' => 189_625)
        )
      end

      it 'rejects a malformed document' do
        expect(subject).to validate(
          :post,
          '/v0/evss_claims/{evss_claim_id}/documents',
          422,
          headers.merge('_data' => { file: fixture_file_upload('malformed-pdf.pdf',
                                                               'application/pdf'),
                                     tracked_item_id: 33,
                                     document_type: 'L023' }, 'evss_claim_id' => 189_625)
        )
      end
    end

    describe 'claim letters' do
      it 'retrieves a list of claim letters metadata' do
        allow(Flipper).to receive(:enabled?)
          .with(:cst_claim_letters_use_lighthouse_api_provider, anything)
          .and_return(false)
        # Response comes from fixture: spec/fixtures/claim_letter/claim_letter_list.json
        expect(subject).to validate(:get, '/v0/claim_letters', 200, headers)
        expect(subject).to validate(:get, '/v0/claim_letters', 401)
      end
    end

    describe 'coe' do
      # The vcr_cassettes used in spec/requests/v0/lgy_coe_request_spec.rb
      # rely on this specific user's edipi and icn, and we are using those
      # cassettes below.
      let(:mhv_user) { create(:evss_user, :loa3, :legacy_icn, edipi: '1007697216') }

      describe 'GET /v0/coe/status' do
        it 'validates the route' do
          VCR.use_cassette 'lgy/determination_eligible' do
            VCR.use_cassette 'lgy/application_not_found' do
              expect(subject).to validate(:get, '/v0/coe/status', 200, headers)
            end
          end
        end
      end

      describe '/v0/coe/documents' do
        it 'validates the route' do
          allow_any_instance_of(User).to receive(:icn).and_return('123498767V234859')
          allow_any_instance_of(User).to receive(:edipi).and_return('1007697216')
          VCR.use_cassette 'lgy/documents_list' do
            expect(subject).to validate(:get, '/v0/coe/documents', 200, headers)
          end
        end
      end

      describe '/v0/coe/submit_coe_claim' do
        it 'validates the route' do
          VCR.use_cassette 'lgy/application_put' do
            # rubocop:disable Layout/LineLength
            params = { lgy_coe_claim: { form: '{"files":[{"name":"Example.pdf","size":60217, "confirmationCode":"a7b6004e-9a61-4e94-b126-518ec9ec9ad0", "isEncrypted":false,"attachmentType":"Discharge or separation papers (DD214)"}],"relevantPriorLoans": [{"dateRange": {"from":"2002-05-01T00:00:00.000Z","to":"2003-01-01T00:00:00. 000Z"},"propertyAddress":{"propertyAddress1":"123 Faker St", "propertyAddress2":"2","propertyCity":"Fake City", "propertyState":"AL","propertyZip":"11111"}, "vaLoanNumber":"111222333444","propertyOwned":true,"intent":"ONETIMERESTORATION"}], "vaLoanIndicator":true,"periodsOfService": [{"serviceBranch":"Air National Guard","dateRange": {"from":"2001-01-01T00:00:00.000Z","to":"2002-02-02T00:00:00. 000Z"}}],"identity":"ADSM","contactPhone":"2222222222", "contactEmail":"veteran@example.com","applicantAddress": {"country":"USA","street":"140 FAKER ST","street2":"2", "city":"FAKE CITY","state":"MT","postalCode":"80129"}, "fullName":{"first":"Alexander","middle":"Guy", "last":"Cook","suffix":"Jr."},"dateOfBirth":"1950-01-01","privacyAgreementAccepted":true}' } }
            # rubocop:enable Layout/LineLength
            expect(subject).to validate(:post, '/v0/coe/submit_coe_claim', 200, headers.merge({ '_data' => params }))
          end
        end
      end

      describe '/v0/coe/document_upload' do
        context 'successful upload' do
          it 'validates the route' do
            VCR.use_cassette 'lgy/document_upload' do
              params = {
                'files' => [{
                  'file' => Base64.encode64(File.read('spec/fixtures/files/lgy_file.pdf')),
                  'document_type' => 'VA home loan documents',
                  'file_type' => 'pdf',
                  'file_name' => 'lgy_file.pdf'
                }]
              }
              expect(subject).to validate(:post, '/v0/coe/document_upload', 200, headers.merge({ '_data' => params }))
            end
          end
        end

        context 'failed upload' do
          it 'validates the route' do
            VCR.use_cassette 'lgy/document_upload_504' do
              params = {
                'files' => [{
                  'file' => Base64.encode64(File.read('spec/fixtures/files/lgy_file.pdf')),
                  'document_type' => 'VA home loan documents',
                  'file_type' => 'pdf',
                  'file_name' => 'lgy_file.pdf'
                }]
              }
              expect(subject).to validate(:post, '/v0/coe/document_upload', 500, headers.merge({ '_data' => params }))
            end
          end
        end
      end
    end

    describe '/v0/profile/contacts' do
      context 'unauthenticated user' do
        it 'returns unauthorized status code' do
          expect(subject).to validate(:get, '/v0/profile/contacts', 401)
        end
      end

      context 'loa1 user' do
        let(:mhv_user) { build(:user, :loa1) }

        it 'returns forbidden status code' do
          expect(subject).to validate(:get, '/v0/profile/contacts', 403, headers)
        end
      end

      context 'loa3 user' do
        let(:idme_uuid) { 'dd681e7d6dea41ad8b80f8d39284ef29' }
        let(:mhv_user) { build(:user, :loa3, idme_uuid:) }

        it 'returns ok status code' do
          VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_200') do
            expect(subject).to validate(:get, '/v0/profile/contacts', 200, headers)
          end
        end
      end
    end

    describe 'travel pay' do
      context 'index' do
        let(:mhv_user) { build(:user, :loa3) }

        it 'returns unauthorized for unauthed user' do
          expect(subject).to validate(:get, '/travel_pay/v0/claims', 401)
        end

        it 'returns 400 for invalid request' do
          headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
          VCR.use_cassette('travel_pay/400_claims', match_requests_on: %i[host path method]) do
            expect(subject).to validate(:get, '/travel_pay/v0/claims', 400, headers)
          end
        end

        it 'returns 200 for successful response' do
          headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
          VCR.use_cassette('travel_pay/200_search_claims_by_appt_date_range', match_requests_on: %i[host path method]) do
            expect(subject).to validate(:get, '/travel_pay/v0/claims', 200, headers)
          end
        end
      end

      context 'show' do
        let(:mhv_user) { build(:user, :loa3) }

        it 'returns unauthorized for unauthed user' do
          expect(subject).to validate(
            :get,
            '/travel_pay/v0/claims/{id}',
            401,
            {}.merge('id' => '24e227ea-917f-414f-b60d-48b7743ee95d')
          )
        end

        # Returns 400 for now, but should be 404
        it 'returns 400 for missing claim' do
          headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
          VCR.use_cassette('travel_pay/404_claim_details', match_requests_on: %i[path method]) do
            expect(subject).to validate(
              :get,
              '/travel_pay/v0/claims/{id}',
              400,
              headers.merge('id' => 'aa0f63e0-5fa7-4d74-a17a-a6f510dbf69e')
            )
          end
        end

        it 'returns 400 for invalid request' do
          headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
          VCR.use_cassette('travel_pay/show/success_details', match_requests_on: %i[path method]) do
            expect(subject).to validate(
              :get,
              '/travel_pay/v0/claims/{id}',
              400,
              headers.merge('id' => '8656')
            )
          end
        end

        it 'returns 200 for successful response' do
          headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
          claim_id = '3fa85f64-5717-4562-b3fc-2c963f66afa6'
          VCR.use_cassette('travel_pay/show/success_details', match_requests_on: %i[path method]) do
            expect(subject).to validate(
              :get,
              '/travel_pay/v0/claims/{id}',
              200,
              headers.merge('id' => claim_id)
            )
          end
        end
      end

      context 'create' do
        let(:mhv_user) { build(:user, :loa3, :with_terms_of_use_agreement) }

        it 'returns unauthorized for unauthorized user' do
          expect(subject).to validate(:post, '/travel_pay/v0/claims', 401)
        end

        it 'returns bad request for missing appointment date time' do
          headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
          VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[path method]) do
            expect(subject).to validate(
              :post,
              '/travel_pay/v0/claims',
              400,
              headers
            )
          end
        end

        it 'returns 201 for successful response' do
          headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
          params = {
            '_data' => {
              'appointment_date_time' => '2024-01-01T16:45:34.465Z',
              'facility_station_number' => '123',
              'appointment_type' => 'Other',
              'is_complete' => false
            }
          }
          VCR.use_cassette('travel_pay/submit/success', match_requests_on: %i[path method]) do
            expect(subject).to validate(
              :post,
              '/travel_pay/v0/claims',
              201,
              headers.merge(params)
            )
          end
        end
      end

      context 'documents' do
        # doc summaries included in claim details

        context 'show' do
          it 'returns unauthorized for unauthed user' do
            expect(subject).to validate(
              :get,
              '/travel_pay/v0/claims/{claimId}/documents/{docId}',
              401,
              {
                'claimId' => 'claim-123',
                'docId' => 'doc-456'
              }
            )
          end
        end
      end
    end

    describe 'banners' do
      describe 'GET /v0/banners' do
        it 'requires path parameter' do
          expect(subject).to validate(:get, '/v0/banners', 422, '_query_string' => 'type=full_width_banner_alert')
        end

        context 'when the service successfully returns banners' do
          it 'supports getting banners without type parameter' do
            VCR.use_cassette('banners/get_banners_success') do
              expect(subject).to validate(:get, '/v0/banners', 200, '_query_string' => 'path=/some-va-path')
            end
          end

          it 'supports getting banners with path and type parameters' do
            VCR.use_cassette('banners/get_banners_with_type_success') do
              expect(subject).to validate(
                :get,
                '/v0/banners',
                200,
                '_query_string' => 'path=full-va-path&type=full_width_banner_alert'
              )
            end
          end
        end
      end
    end

    describe 'submission statuses' do
      context 'loa3 user' do
        let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }
        let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

        before do
          create(:form_submission, :with_form214142, user_account_id: user.user_account_uuid)
          create(:form_submission, :with_form210845, user_account_id: user.user_account_uuid)
          create(:form_submission, :with_form_blocked, user_account_id: user.user_account_uuid)
        end

        it 'submission statuses 200' do
          VCR.use_cassette('forms/submission_statuses/200_valid') do
            expect(subject).to validate(:get, '/v0/my_va/submission_statuses', 200, headers)
          end
        end

        it 'submission statuses 296' do
          VCR.use_cassette('forms/submission_statuses/413_invalid') do
            expect(subject).to validate(:get, '/v0/my_va/submission_statuses', 296, headers)
          end
        end
      end
    end

    describe 'vet verification status' do
      let(:user) { create(:user, :loa3, icn: '1012667145V762142') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      before do
        allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return('blahblech')
      end

      context 'unauthenticated user' do
        it 'returns unauthorized status code' do
          VCR.use_cassette('lighthouse/veteran_verification/status/401_response') do
            expect(subject).to validate(:get, '/v0/profile/vet_verification_status', 401)
          end
        end
      end

      context 'loa3 user' do
        it 'returns ok status code' do
          VCR.use_cassette('lighthouse/veteran_verification/status/200_show_response') do
            expect(subject).to validate(:get, '/v0/profile/vet_verification_status', 200, headers)
          end
        end
      end
    end

    describe 'DatadogAction endpoint' do
      it 'records a front-end metric and returns 204 No Content' do
        body = {
          'metric' => DatadogMetrics::ALLOWLIST.first, # e.g. 'labs_and_tests_list'
          'tags' => []
        }

        expect(subject).to validate(
          :post,
          '/v0/datadog_action',
          204,
          '_data' => body
        )
      end
    end
  end
end

RSpec.describe 'the v1 API documentation', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v1/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob', icn: '1012667145V762142') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    context 'GI Bill Status' do
      it 'supports getting Gi Bill Status' do
        expect(subject).to validate(:get, '/v1/post911_gi_bill_status', 401)
        VCR.use_cassette('lighthouse/benefits_education/200_response') do
          expect(subject).to validate(:get, '/v1/post911_gi_bill_status', 200, headers)
        end
        Timecop.return
      end
    end
  end
end
# rubocop:enable Rspec/MultipleDescribes