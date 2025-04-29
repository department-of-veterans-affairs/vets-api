# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/direct_deposit/configuration'
require 'support/bb_client_helpers'
require 'support/pagerduty/services/spec_setup'
require 'support/stub_debt_letters'
require 'support/medical_copays/stub_medical_copays'
require 'support/stub_efolder_documents'
require_relative '../../modules/debts_api/spec/support/stub_financial_status_report'
require 'support/sm_client_helpers'
require 'support/rx_client_helpers'
require 'bgs/service'
require 'sign_in/logingov/service'
require 'hca/enrollment_eligibility/constants'
require 'form1010_ezr/service'
require 'lighthouse/facilities/v1/client'

RSpec.describe 'API doc validations', type: :request do
  context 'json validation' do
    it 'has valid json' do
      get '/v0/apidocs.json'
      json = response.body
      JSON.parse(json).to_yaml
    end
  end
end

RSpec.describe 'the v0 API documentation', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
    end

    describe 'backend statuses' do
      describe '/v0/backend_statuses' do
        context 'when successful' do
          include_context 'simulating Redis caching of PagerDuty#get_services'

          it 'supports getting external services status data' do
            expect(subject).to validate(:get, '/v0/backend_statuses', 200, headers)
          end
        end

        context 'when the PagerDuty API rate limit has been exceeded' do
          it 'returns a 429 with error details' do
            VCR.use_cassette('pagerduty/external_services/get_services_429') do
              expect(subject).to validate(:get, '/v0/backend_statuses', 429, headers)
            end
          end
        end
      end
    end

    describe 'sign in service' do
      describe 'POST v0/sign_in/token' do
        let(:user_verification) { create(:user_verification) }
        let(:user_verification_id) { user_verification.id }
        let(:grant_type) { 'authorization_code' }
        let(:code) { '0c2d21d3-465b-4054-8030-1d042da4f667' }
        let(:code_verifier) { '5787d673fb784c90f0e309883241803d' }
        let(:code_challenge) { '1BUpxy37SoIPmKw96wbd6MDcvayOYm3ptT-zbe6L_zM' }
        let!(:code_container) do
          create(:code_container,
                 code:,
                 code_challenge:,
                 user_verification_id:,
                 client_id: client_config.client_id)
        end
        let(:client_config) { create(:client_config, enforced_terms: nil) }

        it 'validates the authorization_code & returns tokens' do
          expect(subject).to validate(
            :post,
            '/v0/sign_in/token',
            200,
            '_query_string' => "grant_type=#{grant_type}&code_verifier=#{code_verifier}&code=#{code}"
          )
        end
      end

      describe 'POST v0/sign_in/refresh' do
        let(:user_verification) { create(:user_verification) }
        let(:validated_credential) { create(:validated_credential, user_verification:, client_config:) }
        let(:client_config) { create(:client_config, enforced_terms: nil) }
        let(:session_container) do
          SignIn::SessionCreator.new(validated_credential:).perform
        end
        let(:refresh_token) do
          CGI.escape(SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform)
        end
        let(:refresh_token_param) { { refresh_token: } }

        it 'refreshes the session and returns new tokens' do
          expect(subject).to validate(
            :post,
            '/v0/sign_in/refresh',
            200,
            '_query_string' => "refresh_token=#{refresh_token}"
          )
        end
      end

      describe 'POST v0/sign_in/revoke' do
        let(:user_verification) { create(:user_verification) }
        let(:validated_credential) { create(:validated_credential, user_verification:, client_config:) }
        let(:client_config) { create(:client_config, enforced_terms: nil) }
        let(:session_container) do
          SignIn::SessionCreator.new(validated_credential:).perform
        end
        let(:refresh_token) do
          CGI.escape(SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform)
        end
        let(:refresh_token_param) { { refresh_token: CGI.escape(refresh_token) } }

        it 'revokes the session' do
          expect(subject).to validate(
            :post,
            '/v0/sign_in/revoke',
            200,
            '_query_string' => "refresh_token=#{refresh_token}"
          )
        end
      end

      describe 'GET v0/sign_in/revoke_all_sessions' do
        let(:user_verification) { create(:user_verification) }
        let(:validated_credential) { create(:validated_credential, user_verification:, client_config:) }
        let(:client_config) { create(:client_config, enforced_terms: nil) }
        let(:session_container) do
          SignIn::SessionCreator.new(validated_credential:).perform
        end
        let(:access_token_object) { session_container.access_token }
        let!(:user) { create(:user, :loa3, uuid: access_token_object.user_uuid, middle_name: 'leo') }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }

        it 'revokes the session' do
          expect(subject).to validate(
            :get,
            '/v0/sign_in/revoke_all_sessions',
            200,
            '_headers' => {
              'Authorization' => "Bearer #{access_token}"
            }
          )
        end
      end
    end

    it 'supports listing in-progress forms' do
      expect(subject).to validate(:get, '/v0/in_progress_forms', 200, headers)
      expect(subject).to validate(:get, '/v0/in_progress_forms', 401)
    end

    it 'supports fetching feature_toggles' do
      expect(subject).to validate(:get, '/v0/feature_toggles', 200, features: 'facility_locator')
    end

    it 'supports fetching maintenance windows' do
      expect(subject).to validate(:get, '/v0/maintenance_windows', 200)
    end

    it 'supports getting an in-progress form' do
      create(:in_progress_form, user_uuid: mhv_user.uuid)
      stub_evss_pciu(mhv_user)
      expect(subject).to validate(
        :get,
        '/v0/in_progress_forms/{id}',
        200,
        headers.merge('id' => '1010ez')
      )
      expect(subject).to validate(:get, '/v0/in_progress_forms/{id}', 401, 'id' => '1010ez')
    end

    it 'supports updating an in-progress form' do
      expect(subject).to validate(
        :put,
        '/v0/in_progress_forms/{id}',
        200,
        headers.merge(
          'id' => '1010ez',
          '_data' => { 'form_data' => { wat: 'foo' } }
        )
      )
      expect(subject).to validate(
        :put,
        '/v0/in_progress_forms/{id}',
        500,
        headers.merge('id' => '1010ez')
      )
      expect(subject).to validate(:put, '/v0/in_progress_forms/{id}', 401, 'id' => '1010ez')
    end

    it 'supports deleting an in-progress form' do
      form = create(:in_progress_form, user_uuid: mhv_user.uuid)
      expect(subject).to validate(
        :delete,
        '/v0/in_progress_forms/{id}',
        200,
        headers.merge('id' => form.form_id)
      )
      expect(subject).to validate(:delete, '/v0/in_progress_forms/{id}', 401, 'id' => form.form_id)
    end

    it 'supports getting an disability_compensation_in_progress form' do
      create(:in_progress_526_form, user_uuid: mhv_user.uuid)
      stub_evss_pciu(mhv_user)
      VCR.use_cassette('lighthouse/claims/200_response') do
        expect(subject).to validate(
          :get,
          '/v0/disability_compensation_in_progress_forms/{id}',
          200,
          headers.merge('id' => FormProfiles::VA526ez::FORM_ID)
        )
      end
      expect(subject).to validate(:get, '/v0/disability_compensation_in_progress_forms/{id}',
                                  401,
                                  'id' => FormProfiles::VA526ez::FORM_ID)
    end

    it 'supports updating an disability_compensation_in_progress form' do
      expect(subject).to validate(
        :put,
        '/v0/disability_compensation_in_progress_forms/{id}',
        200,
        headers.merge(
          'id' => FormProfiles::VA526ez::FORM_ID,
          '_data' => { 'form_data' => { wat: 'foo' } }
        )
      )
      expect(subject).to validate(
        :put,
        '/v0/disability_compensation_in_progress_forms/{id}',
        500,
        headers.merge('id' => FormProfiles::VA526ez::FORM_ID)
      )
      expect(subject).to validate(:put, '/v0/disability_compensation_in_progress_forms/{id}',
                                  401,
                                  'id' => FormProfiles::VA526ez::FORM_ID)
    end

    it 'supports deleting an disability_compensation_in_progress form' do
      form = create(:in_progress_526_form, user_uuid: mhv_user.uuid)
      expect(subject).to validate(
        :delete,
        '/v0/disability_compensation_in_progress_forms/{id}',
        200,
        headers.merge('id' => FormProfiles::VA526ez::FORM_ID)
      )
      expect(subject).to validate(:delete, '/v0/disability_compensation_in_progress_forms/{id}',
                                  401,
                                  'id' => form.form_id)
    end

    it 'supports adding an education benefits form' do
      expect(subject).to validate(
        :post,
        '/v0/education_benefits_claims/{form_type}',
        200,
        'form_type' => '1990',
        '_data' => {
          'education_benefits_claim' => {
            'form' => build(:va1990).form
          }
        }
      )

      expect(subject).to validate(
        :post,
        '/v0/education_benefits_claims/{form_type}',
        422,
        'form_type' => '1990',
        '_data' => {
          'education_benefits_claim' => {
            'form' => {}.to_json
          }
        }
      )
    end

    it 'supports adding a claim document' do
      VCR.use_cassette('uploads/validate_document') do
        expect(subject).to validate(
          :post,
          '/v0/claim_attachments',
          200,
          '_data' => {
            'form_id' => '21P-530EZ',
            file: fixture_file_upload('spec/fixtures/files/doctors-note.pdf')
          }
        )

        expect(subject).to validate(
          :post,
          '/v0/claim_attachments',
          422,
          '_data' => {
            'form_id' => '21P-530EZ',
            file: fixture_file_upload('spec/fixtures/files/empty_file.txt')
          }
        )
      end
    end

    it 'supports checking stem_claim_status' do
      expect(subject).to validate(:get, '/v0/education_benefits_claims/stem_claim_status', 200)
    end

    describe '10-10CG' do
      context 'submitting caregiver assistance claim form' do
        it 'successfully submits a caregiver assistance claim' do
          expect_any_instance_of(Form1010cg::Service).to receive(:assert_veteran_status)
          expect(Form1010cg::SubmissionJob).to receive(:perform_async)

          expect(subject).to validate(
            :post,
            '/v0/caregivers_assistance_claims',
            200,
            '_data' => {
              'caregivers_assistance_claim' => {
                'form' => build(:caregivers_assistance_claim).form
              }
            }
          )
        end

        it 'handles 422' do
          expect(subject).to validate(
            :post,
            '/v0/caregivers_assistance_claims',
            422,
            '_data' => {
              'caregivers_assistance_claim' => {
                'form' => {}.to_json
              }
            }
          )
        end
      end

      context 'supports uploading an attachment' do
        it 'handles errors' do
          expect(subject).to validate(
            :post,
            '/v0/form1010cg/attachments',
            400,
            '_data' => {
              'attachment' => {}
            }
          )
        end

        it 'handles 422' do
          expect(subject).to validate(
            :post,
            '/v0/form1010cg/attachments',
            422,
            '_data' => {
              'attachment' => {
                file_data: fixture_file_upload('spec/fixtures/files/doctors-note.gif')
              }
            }
          )
        end

        it 'handles success' do
          VCR.use_cassette 's3/object/put/834d9f51-d0c7-4dc2-9f2e-9b722db98069/doctors-note.pdf', {
            record: :none,
            allow_unused_http_interactions: false,
            match_requests_on: %i[method host]
          } do
            expect(SecureRandom).to receive(:uuid).and_return(
              '834d9f51-d0c7-4dc2-9f2e-9b722db98069'
            )

            allow(SecureRandom).to receive(:uuid).and_call_original

            expect(subject).to validate(
              :post,
              '/v0/form1010cg/attachments',
              200,
              '_data' => {
                'attachment' => {
                  'file_data' => fixture_file_upload('spec/fixtures/files/doctors-note.pdf', 'application/pdf')
                }
              }
            )
          end
        end
      end

      context 'facilities' do
        let(:mock_facility_response) do
          {
            'data' => [
              { 'id' => 'vha_123', 'attributes' => { 'name' => 'Facility 1' } },
              { 'id' => 'vha_456', 'attributes' => { 'name' => 'Facility 2' } }
            ]
          }
        end

        let(:lighthouse_service) { double('FacilitiesApi::V2::Lighthouse::Client') }

        it 'successfully returns list of facilities' do
          expect(FacilitiesApi::V2::Lighthouse::Client).to receive(:new).and_return(lighthouse_service)
          expect(lighthouse_service).to receive(:get_paginated_facilities).and_return(mock_facility_response)

          expect(subject).to validate(
            :post,
            '/v0/caregivers_assistance_claims/facilities',
            200
          )
        end
      end
    end

    it 'supports adding a burial claim', run_at: 'Thu, 29 Aug 2019 17:45:03 GMT' do
      allow(SecureRandom).to receive(:uuid).and_return('c3fa0769-70cb-419a-b3a6-d2563e7b8502')

      VCR.use_cassette(
        'mpi/find_candidate/find_profile_with_attributes',
        VCR::MATCH_EVERYTHING
      ) do
        expect(subject).to validate(
          :post,
          '/burials/v0/claims',
          200,
          '_data' => {
            'burial_claim' => {
              'form' => build(:burial_claim).form
            }
          }
        )

        expect(subject).to validate(
          :post,
          '/burials/v0/claims',
          422,
          '_data' => {
            'burial_claim' => {
              'invalid-form' => { invalid: true }.to_json
            }
          }
        )
      end
    end

    context 'MDOT tests' do
      let(:user_details) do
        {
          first_name: 'Greg',
          last_name: 'Anderson',
          middle_name: 'A',
          birth_date: '1991-04-05',
          ssn: '000550237'
        }
      end

      let(:user) { build(:user, :loa3, user_details) }
      let(:headers) do
        {
          '_headers' => {
            'Cookie' => sign_in(user, nil, true),
            'accept' => 'application/json',
            'content-type' => 'application/json'
          }
        }
      end

      let(:body) do
        {
          'use_veteran_address' => true,
          'use_temporary_address' => false,
          'order' => [{ 'product_id' => 2499 }],
          'permanent_address' => {
            'street' => '125 SOME RD',
            'street2' => 'APT 101',
            'city' => 'DENVER',
            'state' => 'CO',
            'country' => 'United States',
            'postal_code' => '111119999'
          },
          'temporary_address' => {
            'street' => '17250 w colfax ave',
            'street2' => 'a-204',
            'city' => 'Golden',
            'state' => 'CO',
            'country' => 'United States',
            'postal_code' => '80401'
          },
          'vet_email' => 'vet1@va.gov'
        }
      end

      it 'supports creating a MDOT order' do
        expect(subject).to validate(:post, '/v0/mdot/supplies', 401)

        VCR.use_cassette('mdot/submit_order', VCR::MATCH_EVERYTHING) do
          set_mdot_token_for(user)

          expect(subject).to validate(
            :post,
            '/v0/mdot/supplies',
            200,
            headers.merge(
              '_data' => body.to_json
            )
          )
        end
      end
    end

    it 'supports getting cemetaries preneed claim' do
      VCR.use_cassette('preneeds/cemeteries/gets_a_list_of_cemeteries') do
        expect(subject).to validate(
          :get,
          '/v0/preneeds/cemeteries',
          200,
          '_headers' => { 'content-type' => 'application/json' }
        )
      end
    end

    context 'debts tests' do
      let(:user) { build(:user, :loa3) }
      let(:headers) do
        { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
      end

      context 'debt letters index' do
        stub_debt_letters(:index)

        it 'validates the route' do
          expect(subject).to validate(
            :get,
            '/v0/debt_letters',
            200,
            headers
          )
        end
      end

      context 'debt letters show' do
        stub_debt_letters(:show)

        it 'validates the route' do
          expect(subject).to validate(
            :get,
            '/v0/debt_letters/{id}',
            200,
            headers.merge(
              'id' => CGI.escape(document_id)
            )
          )
        end
      end

      context 'debts index' do
        it 'validates the route' do
          VCR.use_cassette('bgs/people_service/person_data') do
            VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
              expect(subject).to validate(
                :get,
                '/v0/debts',
                200,
                headers
              )
            end
          end
        end
      end
    end

    context 'medical copays tests' do
      let(:user) { build(:user, :loa3) }
      let(:headers) do
        { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
      end

      context 'medical copays index' do
        stub_medical_copays(:index)

        it 'validates the route' do
          expect(subject).to validate(
            :get,
            '/v0/medical_copays',
            200,
            headers
          )
        end
      end

      context 'medical copays show' do
        stub_medical_copays_show

        it 'validates the route' do
          expect(subject).to validate(
            :get,
            '/v0/medical_copays/{id}',
            200,
            headers.merge(
              'id' => CGI.escape(id)
            )
          )
        end
      end

      context 'medical copays get_pdf_statement_by_id' do
        stub_medical_copays(:get_pdf_statement_by_id)

        it 'validates the route' do
          expect(subject).to validate(
            :get,
            '/v0/medical_copays/get_pdf_statement_by_id/{statement_id}',
            200,
            headers.merge(
              'statement_id' => CGI.escape(statement_id)
            )
          )
        end
      end

      context 'medical copays send_statement_notifications' do
        let(:headers) do
          { '_headers' => { 'apiKey' => 'abcd1234abcd1234abcd1234abcd1234abcd1234' } }
        end

        it 'validates the route' do
          expect(subject).to validate(
            :post,
            '/v0/medical_copays/send_statement_notifications',
            200,
            headers
          )
        end
      end
    end

    context 'eFolder tests' do
      let(:user) { build(:user, :loa3) }
      let(:headers) do
        { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
      end

      context 'efolder index' do
        stub_efolder_index_documents

        it 'validates the route' do
          expect(subject).to validate(
            :get,
            '/v0/efolder',
            200,
            headers
          )
        end
      end

      context 'efolder show' do
        stub_efolder_show_document

        it 'validates the route' do
          expect(subject).to validate(
            :get,
            '/v0/efolder/{id}',
            200,
            headers.merge(
              'id' => CGI.escape(document_id)
            )
          )
        end
      end
    end

    context 'Financial Status Reports' do
      let(:user) { build(:user, :loa3) }
      let(:headers) do
        { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
      end
      let(:fsr_data) { get_fixture('dmc/fsr_submission') }

      context 'financial status report create' do
        it 'validates the route' do
          pdf_stub = class_double(PdfFill::Filler).as_stubbed_const
          allow(pdf_stub).to receive(:fill_ancillary_form).and_return(Rails.root.join(
            *'/spec/fixtures/dmc/5655.pdf'.split('/')
          ).to_s)
          VCR.use_cassette('dmc/submit_fsr') do
            VCR.use_cassette('bgs/people_service/person_data') do
              expect(subject).to validate(
                :post,
                '/debts_api/v0/financial_status_reports',
                200,
                headers.merge(
                  '_data' => fsr_data
                )
              )
            end
          end
        end
      end
    end

    context 'HCA tests' do
      let(:login_required) { HCA::EnrollmentEligibility::Constants::LOGIN_REQUIRED }
      let(:test_veteran) do
        json_string = Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json').read
        json = JSON.parse(json_string)
        json.delete('email')
        json.to_json
      end
      let(:user) { build(:ch33_dd_user) }
      let(:headers) do
        { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
      end

      it 'supports getting the disability rating' do
        VCR.use_cassette('bgs/service/find_rating_data', VCR::MATCH_EVERYTHING) do
          expect(subject).to validate(
            :get,
            '/v0/health_care_applications/rating_info',
            200,
            headers
          )
        end
      end

      it 'supports getting the hca enrollment status' do
        expect(HealthCareApplication).to receive(:user_icn).and_return('123')
        expect(HealthCareApplication).to receive(:enrollment_status).with(
          '123', nil
        ).and_return(parsed_status: login_required)

        expect(subject).to validate(
          :get,
          '/v0/health_care_applications/enrollment_status',
          200,
          '_query_string' => {
            userAttributes: {
              veteranFullName: {
                first: 'First',
                last: 'last'
              },
              veteranDateOfBirth: '1923-01-02',
              veteranSocialSecurityNumber: '111-11-1234',
              gender: 'F'
            }
          }.to_query
        )
      end

      it 'supports getting the hca health check' do
        VCR.use_cassette('hca/health_check', match_requests_on: [:body]) do
          expect(subject).to validate(
            :get,
            '/v0/health_care_applications/healthcheck',
            200
          )
        end
      end

      it 'supports submitting a hca attachment' do
        expect(subject).to validate(
          :post,
          '/v0/hca_attachments',
          200,
          '_data' => {
            'hca_attachment' => {
              file_data: fixture_file_upload('spec/fixtures/pdf_fill/extras.pdf')
            }
          }
        )
      end

      it 'returns 422 if the attachment is not an allowed type' do
        expect(subject).to validate(
          :post,
          '/v0/hca_attachments',
          422,
          '_data' => {
            'hca_attachment' => {
              file_data: fixture_file_upload('invalid_idme_cert.crt')
            }
          }
        )
      end

      it 'supports getting a health care application state' do
        expect(subject).to validate(
          :get,
          '/v0/health_care_applications/{id}',
          200,
          'id' => create(:health_care_application).id
        )
      end

      it 'returns a 400 if no attachment data is given' do
        expect(subject).to validate(:post, '/v0/hca_attachments', 400, '')
      end

      context "when the 'va1010_forms_enrollment_system_service_enabled' flipper is enabled" do
        before do
          allow(HealthCareApplication).to receive(:user_icn).and_return('123')
        end

        it 'supports submitting a health care application', run_at: '2017-01-31' do
          VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
            expect(subject).to validate(
              :post,
              '/v0/health_care_applications',
              200,
              '_data' => {
                'form' => test_veteran
              }
            )
          end

          expect(subject).to validate(
            :post,
            '/v0/health_care_applications',
            422,
            '_data' => {
              'form' => {}.to_json
            }
          )

          allow_any_instance_of(HCA::Service).to receive(:submit_form) do
            raise Common::Client::Errors::HTTPError, 'error message'
          end

          expect(subject).to validate(
            :post,
            '/v0/health_care_applications',
            400,
            '_data' => {
              'form' => test_veteran
            }
          )
        end
      end

      context "when the 'va1010_forms_enrollment_system_service_enabled' flipper is disabled" do
        before do
          Flipper.disable(:va1010_forms_enrollment_system_service_enabled)
          allow(HealthCareApplication).to receive(:user_icn).and_return('123')
        end

        it 'supports submitting a health care application', run_at: '2017-01-31' do
          VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
            expect(subject).to validate(
              :post,
              '/v0/health_care_applications',
              200,
              '_data' => {
                'form' => test_veteran
              }
            )
          end

          expect(subject).to validate(
            :post,
            '/v0/health_care_applications',
            422,
            '_data' => {
              'form' => {}.to_json
            }
          )

          allow_any_instance_of(HCA::Service).to receive(:post) do
            raise Common::Client::Errors::HTTPError, 'error message'
          end

          expect(subject).to validate(
            :post,
            '/v0/health_care_applications',
            400,
            '_data' => {
              'form' => test_veteran
            }
          )
        end
      end

      context ':hca_cache_facilities feature is off' do
        before { allow(Flipper).to receive(:enabled?).with(:hca_cache_facilities).and_return(false) }

        it 'supports returning list of active facilities' do
          VCR.use_cassette('lighthouse/facilities/v1/200_facilities_facility_ids', match_requests_on: %i[method uri]) do
            expect(subject).to validate(
              :get,
              '/v0/health_care_applications/facilities',
              200,
              { '_query_string' => 'facilityIds[]=vha_757&facilityIds[]=vha_358' }
            )
          end
        end
      end

      context ':hca_cache_facilities feature is on' do
        before { allow(Flipper).to receive(:enabled?).with(:hca_cache_facilities).and_return(true) }

        it 'supports returning list of active facilities' do
          create(:health_facility, name: 'Test Facility', station_number: '123', postal_name: 'OH')

          expect(subject).to validate(
            :get,
            '/v0/health_care_applications/facilities',
            200,
            { '_query_string' => 'state=OH' }
          )
        end
      end
    end

    context 'Form1010Ezr tests' do
      let(:form) do
        json_string = Rails.root.join('spec', 'fixtures', 'form1010_ezr', 'valid_form.json').read
        json = JSON.parse(json_string)
        json.to_json
      end
      let(:user) do
        create(
          :evss_user,
          :loa3,
          icn: '1013032368V065534',
          birth_date: '1986-01-02',
          first_name: 'FirstName',
          middle_name: 'MiddleName',
          last_name: 'ZZTEST',
          suffix: 'Jr.',
          ssn: '111111234',
          gender: 'F'
        )
      end
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      context 'attachments' do
        context 'unauthenticated user' do
          it 'returns unauthorized status code' do
            expect(subject).to validate(
              :post,
              '/v0/form1010_ezr_attachments',
              401
            )
          end
        end

        context 'authenticated' do
          it 'supports submitting an ezr attachment' do
            expect(subject).to validate(
              :post,
              '/v0/form1010_ezr_attachments',
              200,
              headers.merge(
                '_data' => {
                  'form1010_ezr_attachment' => {
                    file_data: fixture_file_upload('spec/fixtures/pdf_fill/extras.pdf')
                  }
                }
              )
            )
          end

          it 'returns 422 if the attachment is not an allowed type' do
            expect(subject).to validate(
              :post,
              '/v0/form1010_ezr_attachments',
              422,
              headers.merge(
                '_data' => {
                  'form1010_ezr_attachment' => {
                    file_data: fixture_file_upload('invalid_idme_cert.crt')
                  }
                }
              )
            )
          end

          it 'returns a 400 if no attachment data is given' do
            expect(subject).to validate(
              :post,
              '/v0/form1010_ezr_attachments',
              400,
              headers
            )
          end

          context 'when a server error occurs' do
            before do
              allow(IO).to receive(:popen).and_return(nil)
            end

            it 'returns a 500' do
              expect(subject).to validate(
                :post,
                '/v0/form1010_ezr_attachments',
                500,
                headers.merge(
                  '_data' => {
                    'form1010_ezr_attachment' => {
                      file_data: fixture_file_upload('spec/fixtures/pdf_fill/extras.pdf')
                    }
                  }
                )
              )
            end
          end
        end
      end

      context 'submitting a 1010EZR form' do
        context 'unauthenticated user' do
          it 'returns unauthorized status code' do
            expect(subject).to validate(:post, '/v0/form1010_ezrs', 401)
          end
        end

        context 'authenticated' do
          it 'supports submitting a 1010EZR application', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
            VCR.use_cassette('form1010_ezr/authorized_submit_with_es_dev_uri', match_requests_on: [:body]) do
              expect(subject).to validate(
                :post,
                '/v0/form1010_ezrs',
                200,
                headers.merge(
                  '_data' => {
                    'form' => form
                  }
                )
              )
            end
          end

          it 'returns a 422 if form validation fails', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
            VCR.use_cassette('form1010_ezr/authorized_submit_with_es_dev_uri', match_requests_on: [:body]) do
              expect(subject).to validate(
                :post,
                '/v0/form1010_ezrs',
                422,
                headers.merge(
                  '_data' => {
                    'form' => {}.to_json
                  }
                )
              )
            end
          end

          it 'returns a 400 if a backend service error occurs', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
            VCR.use_cassette('form1010_ezr/authorized_submit', match_requests_on: [:body]) do
              allow_any_instance_of(Form1010Ezr::Service).to receive(:submit_form) do
                raise Common::Exceptions::BackendServiceException, 'error message'
              end

              expect(subject).to validate(
                :post,
                '/v0/form1010_ezrs',
                400,
                headers.merge(
                  '_data' => {
                    'form' => form
                  }
                )
              )
            end
          end

          it 'returns a 500 if a server error occurs', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
            VCR.use_cassette('form1010_ezr/authorized_submit', match_requests_on: [:body]) do
              allow_any_instance_of(Form1010Ezr::Service).to receive(:submit_form) do
                raise Common::Exceptions::InternalServerError, 'error message'
              end

              expect(subject).to validate(
                :post,
                '/v0/form1010_ezrs',
                500,
                headers.merge(
                  '_data' => {
                    'form' => form
                  }
                )
              )
            end
          end
        end
      end
    end

    describe 'rx tests' do
      include Rx::ClientHelpers
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

      before do
        allow(Rx::Client).to receive(:new).and_return(authenticated_client)
      end

      context 'successful calls' do
        it 'supports getting a list of all prescriptions' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_all_prescriptions') do
            expect(subject).to validate(:get, '/v0/prescriptions', 200, headers)
          end
        end

        it 'supports getting a list of active prescriptions' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_list_of_active_prescriptions') do
            expect(subject).to validate(:get, '/v0/prescriptions/active', 200, headers)
          end
        end

        it 'supports getting details of a particular prescription' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
            expect(subject).to validate(:get, '/v0/prescriptions/{id}', 200, headers.merge('id' => '13650545'))
          end
        end

        it 'supports refilling a prescription' do
          VCR.use_cassette('rx_client/prescriptions/refills_a_prescription') do
            expect(subject).to validate(:patch, '/v0/prescriptions/{id}/refill', 204,
                                        headers.merge('id' => '13650545'))
          end
        end

        it 'supports tracking a prescription' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/gets_tracking_for_a_prescription') do
            expect(subject).to validate(
              :get, '/v0/prescriptions/{prescription_id}/trackings', 200,
              headers.merge('prescription_id' => '13650541')
            )
          end
        end
      end

      context 'unsuccessful calls' do
        it 'returns error on showing a prescription with bad id' do
          VCR.use_cassette('rx_client/prescriptions/gets_a_single_prescription') do
            expect(subject).to validate(:get, '/v0/prescriptions/{id}', 404, headers.merge('id' => '1'))
          end
        end

        it 'returns error on refilling a prescription with bad id' do
          VCR.use_cassette('rx_client/prescriptions/prescription_refill_error') do
            expect(subject).to validate(:patch, '/v0/prescriptions/{id}/refill', 404, headers.merge('id' => '1'))
          end
        end

        it 'returns error on refilling a prescription that is not refillable' do
          VCR.use_cassette('rx_client/prescriptions/prescription_not_refillable_error') do
            expect(subject).to validate(:patch, '/v0/prescriptions/{id}/refill', 400, headers.merge('id' => '1'))
          end
        end

        it 'returns an error tracking a prescription with a bad id' do
          VCR.use_cassette('rx_client/prescriptions/nested_resources/tracking_error_id') do
            expect(subject).to validate(
              :get, '/v0/prescriptions/{prescription_id}/trackings', 404, headers.merge('prescription_id' => '1')
            )
          end
        end
      end
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
      let(:mhv_user) { create(:user, :loa3) }

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

      it 'supports creating an active compensation intent to file' do
        expect(subject).to validate(:post, '/v0/intent_to_file/{type}', 401, 'type' => 'compensation')
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
          expect(subject).to validate(
            :post,
            '/v0/intent_to_file/{type}',
            200,
            headers.update('type' => 'compensation')
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

    describe 'PPIU' do
      let(:mhv_user) { create(:user, :loa3) }

      before do
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:profile_ppiu_reject_requests, instance_of(User))
                                            .and_return(false)
      end

      it 'supports getting payment information' do
        expect(subject).to validate(:get, '/v0/ppiu/payment_information', 401)
        VCR.use_cassette('evss/ppiu/payment_information') do
          expect(subject).to validate(:get, '/v0/ppiu/payment_information', 200, headers)
        end
      end

      it 'supports updating payment information' do
        expect(subject).to validate(:put, '/v0/ppiu/payment_information', 401)
        VCR.use_cassette('evss/ppiu/payment_information') do
          VCR.use_cassette('evss/ppiu/update_payment_information') do
            expect(subject).to validate(
              :put,
              '/v0/ppiu/payment_information',
              200,
              headers.update(
                '_data' => {
                  'account_type' => 'Checking',
                  'financial_institution_name' => 'Bank of Amazing',
                  'account_number' => '1234567890',
                  'financial_institution_routing_number' => '123456789'
                }
              )
            )
          end
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

    # Secure messaging endpoints have been completely removed from the main app
    # and moved to the MyHealth engine.
    # All tests for these endpoints should be in the MyHealth specs.

    describe 'bb' do
      include BB::ClientHelpers

      describe 'health_records' do
        let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

        before do
          allow(BB::Client).to receive(:new).and_return(authenticated_client)
        end

        describe 'show a report' do
          context 'successful calls' do
            it 'supports showing a report' do
              allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

              # Using mucked-up yml because apivore has a problem processing non-json responses
              VCR.use_cassette('bb_client/gets_a_text_report_for_apivore') do
                expect(subject).to validate(:get, '/v0/health_records', 200,
                                            headers.merge('_query_string' => 'doc_type=txt'))
              end
            end
          end

          context 'unsuccessful calls' do
            it 'handles a backend error' do
              allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

              VCR.use_cassette('bb_client/report_error_response') do
                expect(subject).to validate(:get, '/v0/health_records', 503,
                                            headers.merge('_query_string' => 'doc_type=txt'))
              end
            end
          end
        end

        describe 'create a report' do
          context 'successful calls' do
            it 'supports creating a report' do
              allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

              VCR.use_cassette('bb_client/generates_a_report') do
                expect(subject).to validate(
                  :post, '/v0/health_records', 202,
                  headers.merge('_data' => {
                                  'from_date' => 10.years.ago.iso8601.to_json,
                                  'to_date' => Time.now.iso8601.to_json,
                                  'data_classes' => BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES
                                })
                )
              end
            end
          end

          context 'unsuccessful calls' do
            it 'requires from_date, to_date, and data_classes' do
              expect(subject).to validate(
                :post, '/v0/health_records', 422,
                headers.merge('_data' => {
                                'to_date' => Time.now.iso8601.to_json,
                                'data_classes' => BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES.to_json
                              })
              )

              expect(subject).to validate(
                :post, '/v0/health_records', 422,
                headers.merge('_data' => {
                                'from_date' => 10.years.ago.iso8601.to_json,
                                'data_classes' => BB::GenerateReportRequestForm::ELIGIBLE_DATA_CLASSES.to_json
                              })
              )

              expect(subject).to validate(
                :post, '/v0/health_records', 422,
                headers.merge('_data' => {
                                'from_date' => 10.years.ago.iso8601.to_json,
                                'to_date' => Time.now.iso8601.to_json
                              })
              )
            end
          end
        end

        describe 'eligible data classes' do
          it 'supports retrieving eligible data classes' do
            allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

            VCR.use_cassette('bb_client/gets_a_list_of_eligible_data_classes') do
              expect(subject).to validate(:get, '/v0/health_records/eligible_data_classes', 200, headers)
            end
          end
        end

        describe 'refresh' do
          context 'successful calls' do
            it 'supports health records refresh' do
              allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

              VCR.use_cassette('bb_client/gets_a_list_of_extract_statuses') do
                expect(subject).to validate(:get, '/v0/health_records/refresh', 200, headers)
              end
            end
          end

          context 'unsuccessful calls' do
            let(:mhv_user) { build(:user, :loa1) } # a user without mhv_correlation_id

            it 'raises forbidden when user is not eligible' do
              expect(subject).to validate(:get, '/v0/health_records/refresh', 403, headers)
            end
          end
        end
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

      before do
        create(:user_verification, idme_uuid: user.idme_uuid)
      end

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

    describe 'appeals' do
      it 'documents appeals 401' do
        expect(subject).to validate(:get, '/v0/appeals', 401)
      end

      it 'documents appeals 200' do
        VCR.use_cassette('/caseflow/appeals') do
          expect(subject).to validate(:get, '/v0/appeals', 200, headers)
        end
      end

      it 'documents appeals 403' do
        VCR.use_cassette('/caseflow/forbidden') do
          expect(subject).to validate(:get, '/v0/appeals', 403, headers)
        end
      end

      it 'documents appeals 404' do
        VCR.use_cassette('/caseflow/not_found') do
          expect(subject).to validate(:get, '/v0/appeals', 404, headers)
        end
      end

      it 'documents appeals 422' do
        VCR.use_cassette('/caseflow/invalid_ssn') do
          expect(subject).to validate(:get, '/v0/appeals', 422, headers)
        end
      end

      it 'documents appeals 502' do
        VCR.use_cassette('/caseflow/server_error') do
          expect(subject).to validate(:get, '/v0/appeals', 502, headers)
        end
      end
    end

    describe 'appointments' do
      before do
        allow_any_instance_of(User).to receive(:icn).and_return('1234')
      end

      context 'when successful' do
        it 'supports getting appointments data' do
          VCR.use_cassette('ihub/appointments/simple_success') do
            expect(subject).to validate(:get, '/v0/appointments', 200, headers)
          end
        end
      end

      context 'when not signed in' do
        it 'returns a 401 with error details' do
          expect(subject).to validate(:get, '/v0/appointments', 401)
        end
      end

      context 'when iHub experiences an error' do
        it 'returns a 400 with error details' do
          VCR.use_cassette('ihub/appointments/error_occurred') do
            expect(subject).to validate(:get, '/v0/appointments', 400, headers)
          end
        end
      end

      context 'the user does not have an ICN' do
        before do
          allow_any_instance_of(User).to receive(:icn).and_return(nil)
        end

        it 'returns a 502 with error details' do
          expect(subject).to validate(:get, '/v0/appointments', 502, headers)
        end
      end
    end

    describe 'Direct Deposit' do
      let(:user) { create(:user, :loa3, :accountable, icn: '1012666073V986297') }

      before do
        token = 'abcdefghijklmnop'
        allow_any_instance_of(DirectDeposit::Configuration).to receive(:access_token).and_return(token)
      end

      context 'GET' do
        it 'returns a 200' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 200, headers)
          end
        end

        it 'returns a 400' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/errors/400_invalid_icn') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 400, headers)
          end
        end

        it 'returns a 401' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/errors/401_invalid_token') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 401, headers)
          end
        end

        it 'returns a 404' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          VCR.use_cassette('lighthouse/direct_deposit/show/errors/404_response') do
            expect(subject).to validate(:get, '/v0/profile/direct_deposits', 404, headers)
          end
        end
      end

      context 'PUT' do
        it 'returns a 200' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          params = {
            payment_account: { account_number: '1234567890', account_type: 'Checking', routing_number: '031000503' }
          }
          VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
            expect(subject).to validate(:put,
                                        '/v0/profile/direct_deposits',
                                        200,
                                        headers.merge('_data' => params))
          end
        end

        it 'returns a 400' do
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          params = {
            payment_account: { account_number: '1234567890', account_type: 'Checking', routing_number: '031000503' }
          }
          VCR.use_cassette('lighthouse/direct_deposit/update/400_routing_number_fraud') do
            expect(subject).to validate(:put,
                                        '/v0/profile/direct_deposits',
                                        400,
                                        headers.merge('_data' => params))
          end
        end
      end
    end

    describe 'onsite notifications' do
      let(:private_key) { OpenSSL::PKey::EC.new(File.read('spec/support/certificates/notification-private.pem')) }

      before do
        allow_any_instance_of(V0::OnsiteNotificationsController).to receive(:public_key).and_return(
          OpenSSL::PKey::EC.new(
            File.read('spec/support/certificates/notification-public.pem')
          )
        )
      end

      it 'supports onsite_notifications #index' do
        create(:onsite_notification, va_profile_id: mhv_user.vet360_id)
        expect(subject).to validate(:get, '/v0/onsite_notifications', 401)

        expect(subject).to validate(:get, '/v0/onsite_notifications', 200, headers)
      end

      it 'supports updating onsite notifications' do
        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          401,
          'id' => '1'
        )

        onsite_notification = create(:onsite_notification, va_profile_id: mhv_user.vet360_id)

        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          404,
          headers.merge(
            'id' => onsite_notification.id + 1
          )
        )

        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          200,
          headers.merge(
            'id' => onsite_notification.id,
            '_data' => {
              onsite_notification: {
                dismissed: true
              }
            }
          )
        )

        # rubocop:disable Rails/SkipsModelValidations
        onsite_notification.update_column(:template_id, '1')
        # rubocop:enable Rails/SkipsModelValidations
        expect(subject).to validate(
          :patch,
          '/v0/onsite_notifications/{id}',
          422,
          headers.merge(
            'id' => onsite_notification.id,
            '_data' => {
              onsite_notification: {
                dismissed: true
              }
            }
          )
        )
      end

      it 'supports creating onsite notifications' do
        expect(subject).to validate(:post, '/v0/onsite_notifications', 403)

        payload = { user: 'va_notify', iat: Time.current.to_i, exp: 1.minute.from_now.to_i }
        expect(subject).to validate(
          :post,
          '/v0/onsite_notifications',
          200,
          '_headers' => {
            'Authorization' => "Bearer #{JWT.encode(payload, private_key, 'ES256')}"
          },
          '_data' => {
            onsite_notification: {
              template_id: 'f9947b27-df3b-4b09-875c-7f76594d766d',
              va_profile_id: '1'
            }
          }
        )

        payload = { user: 'va_notify', iat: Time.current.to_i, exp: 1.minute.from_now.to_i }
        expect(subject).to validate(
          :post,
          '/v0/onsite_notifications',
          422,
          '_headers' => {
            'Authorization' => "Bearer #{JWT.encode(payload, private_key, 'ES256')}"
          },
          '_data' => {
            onsite_notification: {
              template_id: '1',
              va_profile_id: '1'
            }
          }
        )
      end
    end

    describe 'profiles', :skip_va_profile_user do
      let(:mhv_user) { create(:user, :loa3) }

      it 'supports getting service history data' do
        expect(subject).to validate(:get, '/v0/profile/service_history', 401)
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          expect(subject).to validate(:get, '/v0/profile/service_history', 200, headers)
        end
      end

      it 'supports getting personal information data' do
        expect(subject).to validate(:get, '/v0/profile/personal_information', 401)
        VCR.use_cassette('mpi/find_candidate/valid') do
          VCR.use_cassette('va_profile/demographics/demographics') do
            expect(subject).to validate(:get, '/v0/profile/personal_information', 200, headers)
          end
        end
      end

      it 'supports getting full name data' do
        expect(subject).to validate(:get, '/v0/profile/full_name', 401)

        user = build(:user, :loa3, middle_name: 'Robert')
        headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }

        expect(subject).to validate(:get, '/v0/profile/full_name', 200, headers)
      end

      it 'supports updating a va profile email' do
        expect(subject).to validate(:post, '/v0/profile/email_addresses/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_email_success') do
          email_address = build(:email)

          expect(subject).to validate(
            :post,
            '/v0/profile/email_addresses/create_or_update',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports posting va_profile email address data' do
        expect(subject).to validate(:post, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('va_profile/contact_information/post_email_success') do
          email_address = build(:email)

          expect(subject).to validate(
            :post,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports putting va_profile email address data' do
        expect(subject).to validate(:put, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('va_profile/contact_information/put_email_success') do
          email_address = build(:email, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports deleting va_profile email address data' do
        expect(subject).to validate(:delete, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('va_profile/contact_information/delete_email_success') do
          email_address = build(:email, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports updating va_profile telephone data' do
        expect(subject).to validate(:post, '/v0/profile/telephones/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
          telephone = build(:telephone)

          expect(subject).to validate(
            :post,
            '/v0/profile/telephones/create_or_update',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports posting va_profile telephone data' do
        expect(subject).to validate(:post, '/v0/profile/telephones', 401)

        VCR.use_cassette('va_profile/contact_information/post_telephone_success') do
          telephone = build(:telephone)

          expect(subject).to validate(
            :post,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports putting va_profile telephone data' do
        expect(subject).to validate(:put, '/v0/profile/telephones', 401)

        VCR.use_cassette('va_profile/contact_information/put_telephone_success') do
          telephone = build(:telephone, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports deleting va_profile telephone data' do
        expect(subject).to validate(:delete, '/v0/profile/telephones', 401)

        VCR.use_cassette('va_profile/contact_information/delete_telephone_success') do
          telephone = build(:telephone, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports putting va_profile preferred-name data' do
        expect(subject).to validate(:put, '/v0/profile/preferred_names', 401)

        VCR.use_cassette('va_profile/demographics/post_preferred_name_success') do
          preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')

          expect(subject).to validate(
            :put,
            '/v0/profile/preferred_names',
            200,
            headers.merge('_data' => preferred_name.as_json)
          )
        end
      end

      it 'supports putting va_profile gender-identity data' do
        expect(subject).to validate(:put, '/v0/profile/gender_identities', 401)

        VCR.use_cassette('va_profile/demographics/post_gender_identity_success') do
          gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

          expect(subject).to validate(
            :put,
            '/v0/profile/gender_identities',
            200,
            headers.merge('_data' => gender_identity.as_json)
          )
        end
      end

      context 'communication preferences' do
        before do
          allow_any_instance_of(User).to receive(:vet360_id).and_return('18277')

          headers['_headers'].merge!(
            'accept' => 'application/json',
            'content-type' => 'application/json'
          )
        end

        let(:valid_params) do
          {
            communication_item: {
              id: 2,
              communication_channel: {
                id: 1,
                communication_permission: {
                  allowed: true
                }
              }
            }
          }
        end

        it 'supports the communication preferences update response', run_at: '2021-03-24T23:46:17Z' do
          path = '/v0/profile/communication_preferences/{communication_permission_id}'
          expect(subject).to validate(:patch, path, 401, 'communication_permission_id' => 1)

          VCR.use_cassette('va_profile/communication/put_communication_permissions', VCR::MATCH_EVERYTHING) do
            expect(subject).to validate(
              :patch,
              path,
              200,
              headers.merge(
                '_data' => valid_params.to_json,
                'communication_permission_id' => 46
              )
            )
          end
        end

        it 'supports the communication preferences create response', run_at: '2021-03-24T22:38:21Z' do
          valid_params[:communication_item][:communication_channel][:communication_permission][:allowed] = false
          path = '/v0/profile/communication_preferences'
          expect(subject).to validate(:post, path, 401)

          VCR.use_cassette('va_profile/communication/post_communication_permissions', VCR::MATCH_EVERYTHING) do
            expect(subject).to validate(
              :post,
              path,
              200,
              headers.merge(
                '_data' => valid_params.to_json
              )
            )
          end
        end

        it 'supports the communication preferences index response' do
          path = '/v0/profile/communication_preferences'
          expect(subject).to validate(:get, path, 401)

          VCR.use_cassette('va_profile/communication/get_communication_permissions', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
              expect(subject).to validate(
                :get,
                path,
                200,
                headers
              )
            end
          end
        end
      end

      it 'supports the address validation api' do
        address = build(:va_profile_address, :multiple_matches)
        VCR.use_cassette(
          'va_profile/address_validation/validate_match',
          VCR::MATCH_EVERYTHING
        ) do
          VCR.use_cassette(
            'va_profile/address_validation/candidate_multiple_matches',
            VCR::MATCH_EVERYTHING
          ) do
            expect(subject).to validate(
              :post,
              '/v0/profile/address_validation',
              200,
              headers.merge('_data' => { address: address.to_h })
            )
          end
        end
      end

      it 'supports va_profile create or update address api' do
        expect(subject).to validate(:post, '/v0/profile/addresses/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_address_success') do
          address = build(:va_profile_address)

          expect(subject).to validate(
            :post,
            '/v0/profile/addresses/create_or_update',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports posting va_profile address data' do
        expect(subject).to validate(:post, '/v0/profile/addresses', 401)

        VCR.use_cassette('va_profile/contact_information/post_address_success') do
          address = build(:va_profile_address)

          expect(subject).to validate(
            :post,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports putting va_profile address data' do
        expect(subject).to validate(:put, '/v0/profile/addresses', 401)

        VCR.use_cassette('va_profile/contact_information/put_address_success') do
          address = build(:va_profile_address, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports deleting va_profile address data' do
        expect(subject).to validate(:delete, '/v0/profile/addresses', 401)

        VCR.use_cassette('va_profile/contact_information/delete_address_success') do
          address = build(:va_profile_address, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports updating va_profile permission data' do
        expect(subject).to validate(:post, '/v0/profile/permissions/create_or_update', 401)

        VCR.use_cassette('va_profile/contact_information/put_permission_success') do
          permission = build(:permission)

          expect(subject).to validate(
            :post,
            '/v0/profile/permissions/create_or_update',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports posting va_profile permission data' do
        expect(subject).to validate(:post, '/v0/profile/permissions', 401)

        VCR.use_cassette('va_profile/contact_information/post_permission_success') do
          permission = build(:permission)

          expect(subject).to validate(
            :post,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports putting va_profile permission data' do
        expect(subject).to validate(:put, '/v0/profile/permissions', 401)

        VCR.use_cassette('va_profile/contact_information/put_permission_success') do
          permission = build(:permission, id: 401)

          expect(subject).to validate(
            :put,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports deleting va_profile permission data' do
        expect(subject).to validate(:delete, '/v0/profile/permissions', 401)

        VCR.use_cassette('va_profile/contact_information/delete_permission_success') do
          permission = build(:permission, id: 361) # TODO: ID

          expect(subject).to validate(
            :delete,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports posting to initialize a vet360_id' do
        expect(subject).to validate(:post, '/v0/profile/initialize_vet360_id', 401)
        VCR.use_cassette('va_profile/person/init_vet360_id_success') do
          expect(subject).to validate(
            :post,
            '/v0/profile/initialize_vet360_id',
            200,
            headers.merge('_data' => {})
          )
        end
      end
    end

    describe 'profile/status', :skip_va_profile_user do
      before do
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)

        # vet360_id appears in the API request URI so we need it to match the cassette
        allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
          create(:find_profile_response, profile: build(:mpi_profile, vet360_id: '1'))
        )
      end

      let(:user) { build(:user, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      it 'supports GETting async transaction by ID' do
        transaction = create(
          :va_profile_address_transaction,
          transaction_id: 'a030185b-e88b-4e0d-a043-93e4f34c60d6',
          user_uuid: user.uuid
        )
        expect(subject).to validate(
          :get,
          '/v0/profile/status/{transaction_id}',
          401,
          'transaction_id' => transaction.transaction_id
        )

        VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/status/{transaction_id}',
            200,
            headers.merge('transaction_id' => transaction.transaction_id)
          )
        end
      end

      it 'supports GETting async transactions by user' do
        expect(subject).to validate(
          :get,
          '/v0/profile/status/',
          401
        )

        VCR.use_cassette('va_profile/contact_information/address_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/status/',
            200,
            headers
          )
        end
      end
    end

    describe 'profile/person/status/:transaction_id', :skip_va_profile_user do
      let(:user_without_vet360_id) { build(:user, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user_without_vet360_id, nil, true) } } }

      before do
        allow_any_instance_of(User).to receive(:vet360_id).and_return(nil)
      end

      it 'supports GETting async person transaction by transaction ID' do
        transaction_id = '786efe0e-fd20-4da2-9019-0c00540dba4d'
        transaction = create(
          :va_profile_initialize_person_transaction,
          :init_vet360_id,
          user_uuid: user_without_vet360_id.uuid,
          transaction_id:
        )

        expect(subject).to validate(
          :get,
          '/v0/profile/person/status/{transaction_id}',
          401,
          'transaction_id' => transaction.transaction_id
        )

        VCR.use_cassette('va_profile/contact_information/person_transaction_status') do
          expect(subject).to validate(
            :get,
            '/v0/profile/person/status/{transaction_id}',
            200,
            headers.merge('transaction_id' => transaction.transaction_id)
          )
        end
      end
    end

    describe 'contact infromation v2', :skip_vet360 do
      before do
        allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
        allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
      end

      describe 'profiles v2', :initiate_vaprofile, :skip_vet360 do
        let(:mhv_user) { build(:user, :loa3) }

        before do
          sign_in_as(mhv_user)
        end

        it 'supports getting service history data' do
          allow(Flipper).to receive(:enabled?).with(:profile_show_military_academy_attendance, nil).and_return(false)
          expect(subject).to validate(:get, '/v0/profile/service_history', 401)
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
            expect(subject).to validate(:get, '/v0/profile/service_history', 200, headers)
          end
        end

        it 'supports getting personal information data' do
          expect(subject).to validate(:get, '/v0/profile/personal_information', 401)
          VCR.use_cassette('mpi/find_candidate/valid') do
            VCR.use_cassette('va_profile/demographics/demographics') do
              expect(subject).to validate(:get, '/v0/profile/personal_information', 200, headers)
            end
          end
        end

        it 'supports getting full name data' do
          expect(subject).to validate(:get, '/v0/profile/full_name', 401)

          user = build(:user, :loa3, middle_name: 'Robert')
          headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }

          expect(subject).to validate(:get, '/v0/profile/full_name', 200, headers)
        end

        it 'supports updating a va profile email' do
          expect(subject).to validate(:post, '/v0/profile/email_addresses/create_or_update', 401)
          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            email_address = build(:email, :contact_info_v2)

            expect(subject).to validate(
              :post,
              '/v0/profile/email_addresses/create_or_update',
              200,
              headers.merge('_data' => email_address.as_json)
            )
          end
        end

        it 'supports posting va_profile email address data' do
          expect(subject).to validate(:post, '/v0/profile/email_addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
            email_address = build(:email, :contact_info_v2)

            expect(subject).to validate(
              :post,
              '/v0/profile/email_addresses',
              200,
              headers.merge('_data' => email_address.as_json)
            )
          end
        end

        it 'supports putting va_profile email address data' do
          expect(subject).to validate(:put, '/v0/profile/email_addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/put_email_success') do
            email_address = build(:email, id: 42)

            expect(subject).to validate(
              :put,
              '/v0/profile/email_addresses',
              200,
              headers.merge('_data' => email_address.as_json)
            )
          end
        end

        it 'supports deleting va_profile email address data' do
          expect(subject).to validate(:delete, '/v0/profile/email_addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/delete_email_success') do
            email_address = build(:email, id: 42)

            expect(subject).to validate(
              :delete,
              '/v0/profile/email_addresses',
              200,
              headers.merge('_data' => email_address.as_json)
            )
          end
        end

        it 'supports updating va_profile telephone data' do
          expect(subject).to validate(:post, '/v0/profile/telephones/create_or_update', 401)

          VCR.use_cassette('va_profile/v2/contact_information/put_telephone_success') do
            telephone = build(:telephone, :contact_info_v2)
            expect(subject).to validate(
              :post,
              '/v0/profile/telephones/create_or_update',
              200,
              headers.merge('_data' => telephone.as_json)
            )
          end
        end

        it 'supports posting va_profile telephone data' do
          expect(subject).to validate(:post, '/v0/profile/telephones', 401)

          VCR.use_cassette('va_profile/v2/contact_information/post_telephone_success') do
            telephone = build(:telephone, :contact_info_v2)

            expect(subject).to validate(
              :post,
              '/v0/profile/telephones',
              200,
              headers.merge('_data' => telephone.as_json)
            )
          end
        end

        it 'supports putting va_profile telephone data' do
          expect(subject).to validate(:put, '/v0/profile/telephones', 401)

          VCR.use_cassette('va_profile/v2/contact_information/put_telephone_success') do
            telephone = build(:telephone, id: 42)

            expect(subject).to validate(
              :put,
              '/v0/profile/telephones',
              200,
              headers.merge('_data' => telephone.as_json)
            )
          end
        end

        it 'supports deleting va_profile telephone data' do
          expect(subject).to validate(:delete, '/v0/profile/telephones', 401)

          VCR.use_cassette('va_profile/v2/contact_information/delete_telephone_success') do
            telephone = build(:telephone, id: 42)

            expect(subject).to validate(
              :delete,
              '/v0/profile/telephones',
              200,
              headers.merge('_data' => telephone.as_json)
            )
          end
        end

        it 'supports putting va_profile preferred-name data' do
          expect(subject).to validate(:put, '/v0/profile/preferred_names', 401)

          VCR.use_cassette('va_profile/demographics/post_preferred_name_success') do
            preferred_name = VAProfile::Models::PreferredName.new(text: 'Pat')

            expect(subject).to validate(
              :put,
              '/v0/profile/preferred_names',
              200,
              headers.merge('_data' => preferred_name.as_json)
            )
          end
        end

        it 'supports putting va_profile gender-identity data' do
          expect(subject).to validate(:put, '/v0/profile/gender_identities', 401)

          VCR.use_cassette('va_profile/demographics/post_gender_identity_success') do
            gender_identity = VAProfile::Models::GenderIdentity.new(code: 'F')

            expect(subject).to validate(
              :put,
              '/v0/profile/gender_identities',
              200,
              headers.merge('_data' => gender_identity.as_json)
            )
          end
        end

        it 'supports the address validation api' do
          allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(true)
          address = build(:va_profile_v3_validation_address, :multiple_matches)
          VCR.use_cassette(
            'va_profile/address_validation/validate_match',
            VCR::MATCH_EVERYTHING
          ) do
            VCR.use_cassette(
              'va_profile/v3/address_validation/candidate_multiple_matches',
              VCR::MATCH_EVERYTHING
            ) do
              expect(subject).to validate(
                :post,
                '/v0/profile/address_validation',
                200,
                headers.merge('_data' => { address: address.to_h })
              )
            end
          end
        end

        it 'supports va_profile create or update address api' do
          expect(subject).to validate(:post, '/v0/profile/addresses/create_or_update', 401)
          VCR.use_cassette('va_profile/v2/contact_information/put_address_success') do
            address = build(:va_profile_v3_address, id: 15_035)

            expect(subject).to validate(
              :post,
              '/v0/profile/addresses/create_or_update',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports posting va_profile address data' do
          expect(subject).to validate(:post, '/v0/profile/addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/post_address_success') do
            address = build(:va_profile_v3_address)

            expect(subject).to validate(
              :post,
              '/v0/profile/addresses',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports putting va_profile address data' do
          expect(subject).to validate(:put, '/v0/profile/addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/put_address_success') do
            address = build(:va_profile_v3_address, id: 15_035)

            expect(subject).to validate(
              :put,
              '/v0/profile/addresses',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports deleting va_profile address data' do
          expect(subject).to validate(:delete, '/v0/profile/addresses', 401)

          VCR.use_cassette('va_profile/v2/contact_information/delete_address_success') do
            address = build(:va_profile_v3_address, id: 15_035)

            expect(subject).to validate(
              :delete,
              '/v0/profile/addresses',
              200,
              headers.merge('_data' => address.as_json)
            )
          end
        end

        it 'supports posting to initialize a vet360_id' do
          expect(subject).to validate(:post, '/v0/profile/initialize_vet360_id', 401)
          VCR.use_cassette('va_profile/v2/person/init_vet360_id_success') do
            expect(subject).to validate(
              :post,
              '/v0/profile/initialize_vet360_id',
              200,
              headers.merge('_data' => {})
            )
          end
        end
      end

      describe 'profile/status v2', :initiate_vaprofile, :skip_vet360 do
        let(:user) { build(:user, :loa3) }

        before do
          sign_in_as(user)
        end

        it 'supports GETting async transaction by ID' do
          transaction = create(
            :va_profile_address_transaction,
            transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4',
            user_uuid: user.uuid
          )
          expect(subject).to validate(
            :get,
            '/v0/profile/status/{transaction_id}',
            401,
            'transaction_id' => transaction.transaction_id
          )

          VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
            expect(subject).to validate(
              :get,
              '/v0/profile/status/{transaction_id}',
              200,
              headers.merge('transaction_id' => transaction.transaction_id)
            )
          end
        end

        it 'supports GETting async transactions by user' do
          expect(subject).to validate(
            :get,
            '/v0/profile/status/',
            401
          )

          VCR.use_cassette('va_profile/v2/contact_information/address_transaction_status') do
            expect(subject).to validate(
              :get,
              '/v0/profile/status/',
              200,
              headers
            )
          end
        end
      end

      describe 'profile/person/status/:transaction_id v2' do
        let(:user_without_vet360_id) { build(:user, :loa3) }
        let(:headers) { { '_headers' => { 'Cookie' => sign_in(user_without_vet360_id, nil, true) } } }

        before do
          sign_in_as(user_without_vet360_id)
        end

        it 'supports GETting async person transaction by transaction ID' do
          transaction_id = '153536a5-8b18-4572-a3d9-4030bea3ab5c'
          transaction = create(
            :va_profile_initialize_person_transaction,
            :init_vet360_id,
            user_uuid: user_without_vet360_id.uuid,
            transaction_id:
          )

          expect(subject).to validate(
            :get,
            '/v0/profile/person/status/{transaction_id}',
            401,
            'transaction_id' => transaction.transaction_id
          )

          VCR.use_cassette('va_profile/v2/contact_information/person_transaction_status') do
            expect(subject).to validate(
              :get,
              '/v0/profile/person/status/{transaction_id}',
              200,
              headers.merge('transaction_id' => transaction.transaction_id)
            )
          end
        end
      end
    end

    describe 'profile/connected_applications' do
      let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
      let(:user) { create(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, token, true) } } }

      before do
        Session.create(uuid: user.uuid, token:)
      end

      it 'supports getting connected applications' do
        expect(subject).to validate(:get, '/v0/profile/connected_applications', 401)
        VCR.use_cassette('lighthouse/auth/client_credentials/connected_apps_200') do
          expect(subject).to validate(:get, '/v0/profile/connected_applications', 200, headers)
        end
      end

      it 'supports removing connected applications grants' do
        parameters = { 'application_id' => '0oa2ey2m6kEL2897N2p7' }
        expect(subject).to validate(:delete, '/v0/profile/connected_applications/{application_id}', 401, parameters)
        VCR.use_cassette('lighthouse/auth/client_credentials/revoke_consent_204', allow_playback_repeats: true) do
          expect(subject).to(
            validate(
              :delete,
              '/v0/profile/connected_applications/{application_id}',
              204,
              headers.merge(parameters)
            )
          )
        end
      end
    end

    describe 'when MVI returns an unexpected response body' do
      it 'supports returning a custom 502 response' do
        allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return({
                                                                              service_name: 'oauth_IDME',
                                                                              auth_broker: 'IDME'
                                                                            })

        allow_any_instance_of(MPI::Models::MviProfile).to receive(:gender).and_return(nil)
        allow_any_instance_of(MPI::Models::MviProfile).to receive(:birth_date).and_return(nil)

        VCR.use_cassette('mpi/find_candidate/missing_birthday_and_gender') do
          VCR.use_cassette('va_profile/demographics/demographics') do
            expect(subject).to validate(:get, '/v0/profile/personal_information', 502, headers)
          end
        end
      end
    end

    describe 'when VA Profile returns an unexpected response body' do
      it 'supports returning a custom 400 response' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_500') do
          expect(subject).to validate(:get, '/v0/profile/service_history', 400, headers)
        end
      end
    end

    describe 'search' do
      before do
        Flipper.disable(:search_use_v2_gsa)
      end

      context 'when successful' do
        it 'supports getting search results data' do
          VCR.use_cassette('search/success') do
            expect(subject).to validate(:get, '/v0/search', 200, '_query_string' => 'query=benefits')
          end
        end
      end

      context 'with an empty search query' do
        it 'returns a 400 with error details' do
          VCR.use_cassette('search/empty_query') do
            expect(subject).to validate(:get, '/v0/search', 400, '_query_string' => 'query=')
          end
        end
      end

      context 'when the Search.gov rate limit has been exceeded' do
        it 'returns a 429 with error details' do
          VCR.use_cassette('search/exceeds_rate_limit') do
            expect(subject).to validate(:get, '/v0/search', 429, '_query_string' => 'query=benefits')
          end
        end
      end
    end

    describe 'search click tracking' do
      context 'when successful' do
        # rubocop:disable Layout/LineLength
        let(:params) { { 'position' => 0, 'query' => 'testQuery', 'url' => 'https%3A%2F%2Fwww.testurl.com', 'user_agent' => 'testUserAgent', 'module_code' => 'I14Y' } }

        it 'sends data as query params' do
          VCR.use_cassette('search_click_tracking/success') do
            expect(subject).to validate(:post, '/v0/search_click_tracking/?position={position}&query={query}&url={url}&module_code={module_code}&user_agent={user_agent}', 204, params)
          end
        end
      end

      context 'with an empty search query' do
        let(:params) { { 'position' => 0, 'query' => '', 'url' => 'https%3A%2F%2Fwww.testurl.com', 'user_agent' => 'testUserAgent', 'module_code' => 'I14Y' } }

        it 'returns a 400 with error details' do
          VCR.use_cassette('search_click_tracking/missing_parameter') do
            expect(subject).to validate(:post, '/v0/search_click_tracking/?position={position}&query={query}&url={url}&module_code={module_code}&user_agent={user_agent}', 400, params)
          end
          # rubocop:enable Layout/LineLength
        end
      end
    end

    describe 'search typeahead' do
      context 'when successful' do
        it 'returns an array of suggestions' do
          VCR.use_cassette('search_typeahead/success') do
            expect(subject).to validate(:get, '/v0/search_typeahead', 200, '_query_string' => 'query=ebenefits')
          end
        end
      end

      context 'with an empty search query' do
        it 'returns a 200 with empty results' do
          VCR.use_cassette('search_typeahead/missing_query') do
            expect(subject).to validate(:get, '/v0/search_typeahead', 200, '_query_string' => 'query=')
          end
        end
      end
    end

    describe 'forms' do
      context 'when successful' do
        it 'supports getting form results data with a query' do
          VCR.use_cassette('forms/200_form_query') do
            expect(subject).to validate(:get, '/v0/forms', 200, '_query_string' => 'query=health')
          end
        end

        it 'support getting form results without a query' do
          VCR.use_cassette('forms/200_all_forms') do
            expect(subject).to validate(:get, '/v0/forms', 200)
          end
        end
      end
    end

    describe '1095-B' do
      let(:user) { build(:user, :loa3, icn: '3456787654324567') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }
      let(:bad_headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

      before do
        create(:form1095_b, tax_year: Form1095B.current_tax_year)
      end

      context 'available forms' do
        it 'supports getting available forms' do
          expect(subject).to validate(
            :get,
            '/v0/form1095_bs/available_forms',
            200,
            headers
          )
        end

        it 'requires authorization' do
          expect(subject).to validate(
            :get,
            '/v0/form1095_bs/available_forms',
            401
          )
        end
      end
    end

    describe 'contact us' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
      end

      describe 'POST v0/contact_us/inquiries' do
        let(:post_body) do
          {
            inquiry: {
              form: JSON.generate(
                {
                  personalInformation: {
                    first: 'Obi Wan',
                    last: 'Kenobi'
                  },
                  contactInformation: {
                    email: 'obi1kenobi@gmail.com',
                    address: {
                      country: 'USA'
                    },
                    phone: '1234567890'
                  },
                  topic: {
                    levelOne: 'Caregiver Support Program',
                    levelTwo: 'VA Supportive Services'
                  },
                  inquiryType: 'Question',
                  query: 'Can you help me?',
                  veteranStatus: {
                    veteranStatus: 'general'
                  },
                  preferredContactMethod: 'email'
                }
              )
            }
          }
        end

        it 'supports posting contact us form data' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

          expect(subject).to validate(
            :post,
            '/v0/contact_us/inquiries',
            201,
            headers.merge('_data' => post_body)
          )
        end

        it 'supports validating posted contact us form data' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

          expect(subject).to validate(
            :post,
            '/v0/contact_us/inquiries',
            422,
            headers.merge(
              '_data' => {
                'inquiry' => {
                  'form' => {}.to_json
                }
              }
            )
          )
        end

        it 'supports 501 when feature is disabled' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(false)

          expect(subject).to validate(
            :post,
            '/v0/contact_us/inquiries',
            501,
            headers.merge(
              '_data' => {
                'inquiry' => {
                  'form' => {}.to_json
                }
              }
            )
          )
        end
      end

      describe 'GET v0/contact_us/inquiries' do
        context 'logged in' do
          let(:user) { build(:user, :loa3) }
          let(:headers) do
            { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
          end

          it 'supports getting list of inquiries sent by user' do
            expect(Flipper).to receive(:enabled?).with(:get_help_messages).and_return(true)

            expect(subject).to validate(:get, '/v0/contact_us/inquiries', 200, headers)
          end
        end

        context 'not logged in' do
          it 'returns a 401' do
            expect(subject).to validate(:get, '/v0/contact_us/inquiries', 401)
          end
        end
      end
    end

    describe 'virtual agent' do
      describe 'POST v0/virtual_agent_token' do
        it 'returns webchat token' do
          VCR.use_cassette('virtual_agent/webchat_token_success') do
            expect(subject).to validate(:post, '/v0/virtual_agent_token', 200)
          end
        end
      end
    end

    describe 'dependents applications' do
      context 'when :va_dependents_v2 is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:va_dependents_submit674, instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
        end

        let!(:user) { build(:user, ssn: '796043735') }

        it 'supports getting dependent information' do
          expect(subject).to validate(:get, '/v0/dependents_applications/show', 401)
          VCR.use_cassette('bgs/claimant_web_service/dependents') do
            expect(subject).to validate(:get, '/v0/dependents_applications/show', 200, headers)
          end
        end

        it 'supports adding a dependency claim' do
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(false)
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
          allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            expect(subject).to validate(
              :post,
              '/v0/dependents_applications',
              200,
              headers.merge(
                '_data' => build(:dependency_claim).parsed_form
              )
            )
          end

          expect(subject).to validate(
            :post,
            '/v0/dependents_applications',
            422,
            headers.merge(
              '_data' => {
                'dependency_claim' => {
                  'invalid-form' => { invalid: true }.to_json
                }
              }
            )
          )
        end
      end

      context 'when :va_dependents_v2 is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:va_dependents_submit674, instance_of(User)).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
        end

        let!(:user) { build(:user, ssn: '796043735') }

        it 'supports getting dependent information' do
          expect(subject).to validate(:get, '/v0/dependents_applications/show', 401)
          VCR.use_cassette('bgs/claimant_web_service/dependents') do
            expect(subject).to validate(:get, '/v0/dependents_applications/show', 200, headers)
          end
        end

        it 'supports adding a dependency claim' do
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(false)
          allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
          allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            expect(subject).to validate(
              :post,
              '/v0/dependents_applications',
              200,
              headers.merge(
                '_data' => build(:dependency_claim).parsed_form
              )
            )
          end

          expect(subject).to validate(
            :post,
            '/v0/dependents_applications',
            422,
            headers.merge(
              '_data' => {
                'dependency_claim' => {
                  'invalid-form' => { invalid: true }.to_json
                }
              }
            )
          )
        end
      end
    end

    describe 'dependents verifications' do
      it 'supports getting diary information' do
        expect(subject).to validate(:get, '/v0/dependents_verifications', 401)
        VCR.use_cassette('bgs/diaries/read') do
          expect(subject).to validate(:get, '/v0/dependents_verifications', 200, headers)
        end
      end

      it 'supports updating diaries' do
        expect(subject).to validate(
          :post,
          '/v0/dependents_verifications',
          200,
          headers.merge(
            '_data' => {
              'dependency_verification_claim' => {
                'form' => { 'update_diaries' => 'true' }
              }
            }
          )
        )
      end
    end

    describe 'education career counseling claims' do
      it 'supports adding a career counseling claim' do
        expect(subject).to validate(
          :post,
          '/v0/education_career_counseling_claims',
          200,
          headers.merge(
            '_data' => {
              'education_career_counseling_claim' => {
                form: build(:education_career_counseling_claim).form
              }
            }
          )
        )

        expect(subject).to validate(
          :post,
          '/v0/education_career_counseling_claims',
          422,
          headers.merge(
            '_data' => {
              'education_career_counseling_claim' => {
                'invalid-form' => { invalid: true }.to_json
              }
            }
          )
        )
      end
    end

    describe 'veteran readiness employment claims' do
      it 'supports adding veteran readiness employment claim' do
        VCR.use_cassette('veteran_readiness_employment/send_to_vre') do
          allow(ClaimsApi::VBMSUploader).to receive(:new) { OpenStruct.new(upload!: true) }
          expect(subject).to validate(
            :post,
            '/v0/veteran_readiness_employment_claims',
            200,
            headers.merge(
              '_data' => {
                'veteran_readiness_employment_claim' => {
                  form: build(:veteran_readiness_employment_claim).form
                }
              }
            )
          )
        end
      end

      it 'throws an error when adding veteran readiness employment claim' do
        expect(subject).to validate(
          :post,
          '/v0/veteran_readiness_employment_claims',
          422,
          headers.merge(
            '_data' => {
              'veteran_readiness_employment_claim' => {
                'invalid-form' => { invalid: true }.to_json
              }
            }
          )
        )
      end
    end

    describe 'va file number' do
      it 'supports checking if a user has a veteran number' do
        expect(subject).to validate(:get, '/v0/profile/valid_va_file_number', 401)
        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          expect(subject).to validate(:get, '/v0/profile/valid_va_file_number', 200, headers)
        end
      end
    end

    it "supports returning the vet's payment_history" do
      expect(subject).to validate(:get, '/v0/profile/payment_history', 401)
      VCR.use_cassette('bgs/payment_history/retrieve_payment_summary_with_bdn') do
        expect(subject).to validate(:get, '/v0/profile/payment_history', 200, headers)
      end
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
        # Response comes from fixture: spec/fixtures/claim_letter/claim_letter_list.json
        expect(subject).to validate(:get, '/v0/claim_letters', 200, headers)
        expect(subject).to validate(:get, '/v0/claim_letters', 401)
      end
    end

    describe 'coe' do
      # The vcr_cassettes used in spec/requests/v0/lgy_coe_request_spec.rb
      # rely on this specific user's edipi and icn, and we are using those
      # cassettes below.
      let(:mhv_user) { create(:evss_user, :loa3) }

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
  end

  describe 'travel pay' do
    context 'index' do
      let(:mhv_user) { build(:user, :loa3) }

      it 'returns unauthorized for unauthed user' do
        expect(subject).to validate(:get, '/travel_pay/v0/claims', 401)
      end

      it 'returns 400 for invalid request' do
        headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
        VCR.use_cassette('travel_pay/404_claims', match_requests_on: %i[host path method]) do
          expect(subject).to validate(:get, '/travel_pay/v0/claims', 400, headers)
        end
      end

      it 'returns 200 for successful response' do
        headers = { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } }
        VCR.use_cassette('travel_pay/200_claims', match_requests_on: %i[host path method]) do
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
      let(:mhv_user) { build(:user, :loa3) }

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

  context 'and' do
    before do
      allow(HealthCareApplication).to receive(:user_icn).and_return('123')
    end

    it 'tests all documented routes' do
      # exclude these route as they return binaries
      subject.untested_mappings.delete('/v0/letters/{id}')
      subject.untested_mappings.delete('/debts_api/v0/financial_status_reports/download_pdf')
      subject.untested_mappings.delete('/v0/form1095_bs/download_pdf/{tax_year}')
      subject.untested_mappings.delete('/v0/form1095_bs/download_txt/{tax_year}')
      subject.untested_mappings.delete('/v0/claim_letters/{document_id}')
      subject.untested_mappings.delete('/v0/coe/download_coe')
      subject.untested_mappings.delete('/v0/coe/document_download/{id}')
      subject.untested_mappings.delete('/v0/caregivers_assistance_claims/download_pdf')
      subject.untested_mappings.delete('/v0/health_care_applications/download_pdf')
      subject.untested_mappings.delete('/v0/form0969')

      # SiS methods that involve forms & redirects
      subject.untested_mappings.delete('/v0/sign_in/authorize')
      subject.untested_mappings.delete('/v0/sign_in/callback')
      subject.untested_mappings.delete('/v0/sign_in/logout')

      # Delete all secure messaging endpoints - this functionality has been moved to MyHealth engine
      subject.untested_mappings.keys.dup.each do |path|
        subject.untested_mappings.delete(path) if path.include?('/v0/messaging/health/')
      end

      expect(subject).to validate_all_paths
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
