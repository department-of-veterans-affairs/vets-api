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

RSpec.describe 'the v0 API documentation (Part 3)', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
    end

    describe 'disability compensation' do
      before do
        create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: mhv_user.uuid)
        Flipper.disable('disability_compensation_prevent_submission_job')
        Flipper.disable('disability_compensation_production_tester')
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
        allow_any_instance_of(User).to receive(:icn).and_return('123498767V234859')
      end

      let(:form526v2) do
        Rails.root.join('spec', 'support', 'disability_compensation_form', 'all_claims_fe_submission.json').read
      end

      it 'supports getting rated disabilities' do
        expect(subject).to validate(:get, '/v0/disability_compensation_form/rated_disabilities', 401)
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rated_disabilities', 200, headers)
        end
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/400_response') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rated_disabilities', 400, headers)
        end
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/502_response') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rated_disabilities', 502, headers)
        end
      end

      context 'with a loa1 user' do
        let(:mhv_user) { build(:user, :loa1) }

        it 'returns error on getting rated disabilities without evss authorization' do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rated_disabilities', 403, headers)
        end

        it 'returns error on getting separation_locations' do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/separation_locations', 403, headers)
        end

        it 'returns error on submit_all_claim' do
          expect(subject).to validate(
            :post,
            '/v0/disability_compensation_form/submit_all_claim',
            403,
            headers.update(
              '_data' => form526v2
            )
          )
        end

        it 'returns error on getting submission status' do
          expect(subject).to validate(
            :get,
            '/v0/disability_compensation_form/submission_status/{job_id}',
            403,
            headers.update(
              '_data' => form526v2,
              'job_id' => 123
            )
          )
        end

        it 'returns error on getting rating info' do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rating_info', 403, headers)
        end
      end

      it 'supports getting separation_locations' do
        expect(subject).to validate(:get, '/v0/disability_compensation_form/separation_locations', 401)
        VCR.use_cassette('brd/separation_locations_502') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/separation_locations', 502, headers)
        end
        VCR.use_cassette('brd/separation_locations_503') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/separation_locations', 503, headers)
        end
        VCR.use_cassette('brd/separation_locations') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/separation_locations', 200, headers)
        end
      end

      it 'supports getting suggested conditions' do
        create(:disability_contention_arrhythmia)
        expect(subject).to validate(
          :get,
          '/v0/disability_compensation_form/suggested_conditions{params}',
          401,
          'params' => '?name_part=arr'
        )
        expect(subject).to validate(
          :get,
          '/v0/disability_compensation_form/suggested_conditions{params}',
          200,
          headers.merge('params' => '?name_part=arr')
        )
      end

      it 'supports submitting the v2 form' do
        allow(EVSS::DisabilityCompensationForm::SubmitForm526)
          .to receive(:perform_async).and_return('57ca1a62c75e551fd2051ae9')
        expect(subject).to validate(:post, '/v0/disability_compensation_form/submit_all_claim', 401)
        expect(subject).to validate(:post, '/v0/disability_compensation_form/submit_all_claim', 422,
                                    headers.update('_data' => '{ "form526": "foo"}'))
        expect(subject).to validate(
          :post,
          '/v0/disability_compensation_form/submit_all_claim',
          200,
          headers.update('_data' => form526v2)
        )
      end

      context 'with a submission and job status' do
        let(:submission) { create(:form526_submission, submitted_claim_id: 61_234_567) }
        let(:job_status) { create(:form526_job_status, form526_submission_id: submission.id) }

        it 'supports getting submission status' do
          expect(subject).to validate(
            :get,
            '/v0/disability_compensation_form/submission_status/{job_id}',
            401,
            'job_id' => job_status.job_id
          )
          expect(subject).to validate(
            :get,
            '/v0/disability_compensation_form/submission_status/{job_id}',
            404,
            headers.merge('job_id' => 'invalid_id')
          )
          expect(subject).to validate(
            :get,
            '/v0/disability_compensation_form/submission_status/{job_id}',
            200,
            headers.merge('job_id' => job_status.job_id)
          )
        end
      end

      context 'when calling EVSS' do
        before do
          # TODO: remove Flipper feature toggle when lighthouse provider is implemented
          allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, instance_of(User))
                                              .and_return(false)
        end

        it 'supports getting rating info' do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rating_info', 401)

          VCR.use_cassette('evss/disability_compensation_form/rating_info') do
            expect(subject).to validate(:get, '/v0/disability_compensation_form/rating_info', 200, headers)
          end
        end
      end
    end

    describe 'intent to file' do
      let(:mhv_user) { create(:user, :loa3, :legacy_icn) }

      before do
        Flipper.disable('disability_compensation_production_tester')
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
      end

      it 'supports getting all intent to file' do
        expect(subject).to validate(:get, '/v0/intent_to_file', 401)
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
          expect(subject).to validate(:get, '/v0/intent_to_file', 200, headers)
        end
      end

      it 'supports getting a specific type of intent to file' do
        expect(subject).to validate(:get, '/v0/intent_to_file/{itf_type}', 401, 'itf_type' => 'pension')
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response_pension') do
          expect(subject).to validate(
            :get,
            '/v0/intent_to_file/{itf_type}',
            200,
            headers.update('itf_type' => 'pension')
          )
        end
      end

      it 'supports creating an active compensation intent to file' do
        expect(subject).to validate(:post, '/v0/intent_to_file/{itf_type}', 401, 'itf_type' => 'compensation')
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
          expect(subject).to validate(
            :post,
            '/v0/intent_to_file/{itf_type}',
            200,
            headers.update('itf_type' => 'compensation')
          )
        end
      end
    end

    describe 'MVI Users' do
      context 'when user is correct' do
        let(:mhv_user) { build(:user_with_no_ids) }

        it 'fails when invalid form id is passed' do
          expect(subject).to validate(:post, '/v0/mvi_users/{id}', 403, headers.merge('id' => '12-1234'))
        end

        it 'when correct form id is passed, it supports creating mvi user' do
          VCR.use_cassette('mpi/add_person/add_person_success') do
            VCR.use_cassette('mpi/find_candidate/orch_search_with_attributes') do
              VCR.use_cassette('mpi/find_candidate/find_profile_with_identifier') do
                expect(subject).to validate(:post, '/v0/mvi_users/{id}', 200, headers.merge('id' => '21-0966'))
              end
            end
          end
        end
      end

      it 'fails when no user information is passed' do
        expect(subject).to validate(:post, '/v0/mvi_users/{id}', 401, 'id' => '21-0966')
      end

      context 'when user is missing birls only' do
        let(:mhv_user) { build(:user, :loa3, birls_id: nil) }

        it 'fails with 422' do
          expect(subject).to validate(:post, '/v0/mvi_users/{id}', 422, headers.merge('id' => '21-0966'))
        end
      end
    end

    describe 'supporting evidence upload' do
      it 'supports uploading a file' do
        expect(subject).to validate(
          :post,
          '/v0/upload_supporting_evidence',
          200,
          headers.update(
            '_data' => {
              'supporting_evidence_attachment' => {
                'file_data' => fixture_file_upload('spec/fixtures/pdf_fill/extras.pdf')
              }
            }
          )
        )
      end

      it 'returns a 400 if no attachment data is given' do
        expect(subject).to validate(
          :post,
          '/v0/upload_supporting_evidence',
          400,
          headers
        )
      end

      it 'returns a 422 if a file is corrupted or invalid' do
        expect(subject).to validate(
          :post,
          '/v0/upload_supporting_evidence',
          422,
          headers.update(
            '_data' => {
              'supporting_evidence_attachment' => {
                'file_data' => fixture_file_upload('malformed-pdf.pdf')
              }
            }
          )
        )
      end
    end

    describe 'gibct' do
      describe 'yellow_ribbon_programs' do
        describe 'index' do
          it 'supports showing a list of yellow_ribbon_programs' do
            VCR.use_cassette('gi_client/gets_yellow_ribbon_programs_search_results') do
              expect(subject).to validate(:get, '/v0/gi/yellow_ribbon_programs', 200)
            end
          end
        end
      end

      describe 'institutions' do
        describe 'autocomplete' do
          it 'supports autocomplete of institution names' do
            VCR.use_cassette('gi_client/gets_a_list_of_institution_autocomplete_suggestions') do
              expect(subject).to validate(
                :get, '/v0/gi/institutions/autocomplete', 200, '_query_string' => 'term=university'
              )
            end
          end
        end

        describe 'search' do
          it 'supports autocomplete of institution names' do
            VCR.use_cassette('gi_client/gets_institution_search_results') do
              expect(subject).to validate(
                :get, '/v0/gi/institutions/search', 200, '_query_string' => 'name=illinois'
              )
            end
          end
        end

        describe 'show' do
          context 'successful calls' do
            it 'supports showing institution details' do
              VCR.use_cassette('gi_client/gets_the_institution_details') do
                expect(subject).to validate(:get, '/v0/gi/institutions/{id}', 200, 'id' => '11902614')
              end
            end
          end

          context 'unsuccessful calls' do
            it 'returns error on refilling a prescription with bad id' do
              VCR.use_cassette('gi_client/gets_institution_details_error') do
                expect(subject).to validate(:get, '/v0/gi/institutions/{id}', 404, 'id' => 'splunge')
              end
            end
          end
        end
      end

      describe 'calculator_constants' do
        it 'supports getting all calculator constants' do
          VCR.use_cassette('gi_client/gets_the_calculator_constants') do
            expect(subject).to validate(
              :get, '/v0/gi/calculator_constants', 200
            )
          end
        end
      end

      describe 'institution programs' do
        describe 'autocomplete' do
          it 'supports autocomplete of institution names' do
            VCR.use_cassette('gi_client/gets_a_list_of_institution_program_autocomplete_suggestions') do
              expect(subject).to validate(
                :get, '/v0/gi/institution_programs/autocomplete', 200, '_query_string' => 'term=code'
              )
            end
          end
        end

        describe 'search' do
          it 'supports autocomplete of institution names' do
            VCR.use_cassette('gi_client/gets_institution_program_search_results') do
              expect(subject).to validate(
                :get, '/v0/gi/institution_programs/search', 200, '_query_string' => 'name=code'
              )
            end
          end
        end
      end
    end

    context 'with a loa1 user' do
      let(:mhv_user) { build(:user, :loa1) }

      it 'rejects getting EVSS Letters for loa1 users' do
        expect(subject).to validate(:get, '/v0/letters', 403, headers)
      end

      it 'rejects getting EVSS benefits Letters for loa1 users' do
        expect(subject).to validate(:get, '/v0/letters/beneficiary', 403, headers)
      end
    end

    context 'without EVSS mock' do
      before do
        allow(Settings.evss).to receive_messages(mock_gi_bill_status: false, mock_letters: false)
      end

      it 'supports getting EVSS Letters' do
        expect(subject).to validate(:get, '/v0/letters', 401)
        VCR.use_cassette('evss/letters/letters') do
          expect(subject).to validate(:get, '/v0/letters', 200, headers)
        end
      end

      it 'supports getting EVSS Letters Beneficiary' do
        expect(subject).to validate(:get, '/v0/letters/beneficiary', 401)
        VCR.use_cassette('evss/letters/beneficiary') do
          expect(subject).to validate(:get, '/v0/letters/beneficiary', 200, headers)
        end
      end

      it 'supports posting EVSS Letters' do
        expect(subject).to validate(:post, '/v0/letters/{id}', 401, 'id' => 'commissary')
      end
    end

    it 'supports getting the 200 user data' do
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', match_requests_on: %i[body],
                                                                                  allow_playback_repeats: true) do
        expect(subject).to validate(:get, '/v0/user', 200, headers)
      end
    end

    it 'supports getting the 401 user data' do
      VCR.use_cassette('va_profile/veteran_status/veteran_status_401_oid_blank', match_requests_on: %i[body],
                                                                                 allow_playback_repeats: true) do
        expect(subject).to validate(:get, '/v0/user', 401)
      end
    end

    context '/v0/user endpoint with some external service errors' do
      let(:user) { build(:user, middle_name: 'Lee') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      it 'supports getting user with some external errors', :skip_mvi do
        expect(subject).to validate(:get, '/v0/user', 296, headers)
      end
    end

    describe 'Lighthouse Benefits Reference Data' do
      it 'gets disabilities data from endpoint' do
        VCR.use_cassette('lighthouse/benefits_reference_data/200_disabilities_response') do
          expect(subject).to validate(
            :get,
            '/v0/benefits_reference_data/{path}',
            200,
            headers.merge('path' => 'disabilities')
          )
        end
      end

      it 'gets intake-sites data from endpoint' do
        VCR.use_cassette('lighthouse/benefits_reference_data/200_intake_sites_response') do
          expect(subject).to validate(
            :get,
            '/v0/benefits_reference_data/{path}',
            200,
            headers.merge('path' => 'intake-sites')
          )
        end
      end
    end

    describe 'Event Bus Gateway' do
      include_context 'with service account authentication', 'eventbus', ['http://www.example.com/v0/event_bus_gateway/send_email'], { user_attributes: { participant_id: '1234' } }

      context 'when sending emails' do
        let(:params) do
          {
            template_id: '5678'
          }
        end

        it 'documents an unauthenticated request' do
          expect(subject).to validate(:post, '/v0/event_bus_gateway/send_email', 401)
        end

        it 'documents a success' do
          expect(subject).to validate(
            :post,
            '/v0/event_bus_gateway/send_email',
            200,
            '_headers' => service_account_auth_header,
            '_data' => params
          )
        end
      end
    end
  end
end