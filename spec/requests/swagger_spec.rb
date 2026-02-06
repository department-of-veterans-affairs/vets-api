# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/direct_deposit/configuration'
require 'support/bb_client_helpers'
require 'support/pagerduty/services/spec_setup'
require 'support/stub_debt_letters'
require 'support/medical_copays/stub_medical_copays'
require 'support/stub_efolder_documents'
require_relative '../../modules/debts_api/spec/support/stub_financial_status_report'
require 'bgs/service'
require 'sign_in/logingov/service'
require 'hca/enrollment_eligibility/constants'
require 'form1010_ezr/service'
require 'lighthouse/facilities/v1/client'
require 'debts_api/v0/digital_dispute_dmc_service'
require 'veteran_status_card/service'

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
  let(:json_headers) do
    {
      '_headers' => {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    }
  end

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
      allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
      allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
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

    it 'supports getting an in-progress form', :initiate_vaprofile do
      create(:in_progress_form, user_uuid: mhv_user.uuid)
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

    it 'supports getting an disability_compensation_in_progress form', :initiate_vaprofile do
      create(:in_progress_526_form, user_uuid: mhv_user.uuid)
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

    it 'supports adding a claim document', :skip_va_profile_user do
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
          form_attachment = build(:form1010cg_attachment, :with_attachment)

          allow_any_instance_of(FormAttachmentCreate).to receive(:save_attachment_to_cloud!).and_return(true)
          allow_any_instance_of(FormAttachmentCreate).to receive(:form_attachment).and_return(form_attachment)

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
              'form' => build(:burials_saved_claim).form
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

    it 'supports adding a pension claim' do
      allow(SecureRandom).to receive(:uuid).and_return('c3fa0769-70cb-419a-b3a6-d2563e7b8502')

      VCR.use_cassette(
        'mpi/find_candidate/find_profile_with_attributes',
        VCR::MATCH_EVERYTHING
      ) do
        expect(subject).to validate(
          :post,
          '/pensions/v0/claims',
          200,
          '_data' => {
            'pension_claim' => {
              'form' => build(:pensions_saved_claim).form
            }
          }
        )

        expect(subject).to validate(
          :post,
          '/pensions/v0/claims',
          422,
          '_data' => {
            'pension_claim' => {
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
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          }
        }
      end

      let(:body) do
        {
          'use_veteran_address' => true,
          'use_temporary_address' => false,
          'order' => [{ 'product_id' => 6650 }, { 'product_id' => 8271 }],
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

        VCR.use_cassette('mdot/submit_order_multi_orders', VCR::MATCH_EVERYTHING) do
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

      context 'digital disputes' do
        let(:pdf_file) do
          fixture_file_upload('spec/fixtures/pdf_fill/686C-674/tester.pdf', 'application/pdf')
        end
        let(:metadata_json) do
          {
            'disputes' => [
              {
                'composite_debt_id' => '71166',
                'deduction_code' => '71',
                'original_ar' => 166.67,
                'current_ar' => 120.4,
                'benefit_type' => 'CH33 Books, Supplies/MISC EDU',
                'dispute_reason' => "I don't think I owe this debt to VA"
              }
            ]
          }.to_json
        end

        it 'validates the route' do
          allow_any_instance_of(DebtsApi::V0::DigitalDisputeDmcService).to receive(:call!)
          expect(subject).to validate(
            :post,
            '/debts_api/v0/digital_disputes',
            200,
            headers.merge(
              '_data' => { metadata: metadata_json, files: [pdf_file] }
            )
          )
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

      describe 'financial status report submissions' do
        it 'supports getting financial status report submissions' do
          expect(subject).to validate(
            :get,
            '/debts_api/v0/financial_status_reports/submissions',
            200,
            headers
          )
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

      context 'authorized user' do
        it 'supports getting the hca enrollment status' do
          expect(HealthCareApplication).to receive(:enrollment_status).with(
            user.icn, true
          ).and_return(parsed_status: login_required)

          expect(subject).to validate(
            :get,
            '/v0/health_care_applications/enrollment_status',
            200,
            headers
          )
        end
      end

      it 'supports getting the hca enrollment status with post call' do
        expect(HealthCareApplication).to receive(:user_icn).and_return('123')
        expect(HealthCareApplication).to receive(:enrollment_status).with(
          '123', nil
        ).and_return(parsed_status: login_required)

        expect(subject).to validate(
          :post,
          '/v0/health_care_applications/enrollment_status',
          200,
          '_data' => {
            userAttributes: {
              veteranFullName: {
                first: 'First',
                last: 'last'
              },
              veteranDateOfBirth: '1923-01-02',
              veteranSocialSecurityNumber: '111-11-1234',
              gender: 'F'
            }
          }
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

      it 'supports submitting a health care application', run_at: '2017-01-31' do
        allow(HealthCareApplication).to receive(:user_icn).and_return('123')

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

      context ':hca_cache_facilities feature is off' do
        before { allow(Flipper).to receive(:enabled?).with(:hca_cache_facilities).and_return(false) }

        it 'supports returning list of active facilities' do
          mock_job = instance_double(HCA::HealthFacilitiesImportJob)
          expect(HCA::HealthFacilitiesImportJob).to receive(:new).and_return(mock_job)
          expect(mock_job).to receive(:perform)
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
          before do
            allow_any_instance_of(
              Form1010Ezr::VeteranEnrollmentSystem::Associations::Service
            ).to receive(:reconcile_and_update_associations).and_return(
              {
                status: 'success',
                message: 'All associations were updated successfully',
                timestamp: Time.current.iso8601
              }
            )
          end

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

      context 'downloading a 1010EZR pdf form' do
        context 'unauthenticated user' do
          it 'returns unauthorized status code' do
            expect(subject).to validate(:post, '/v0/form1010_ezrs/download_pdf', 401)
          end
        end
      end
    end

    describe 'disability compensation' do
      before do
        create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: mhv_user.uuid)
        Flipper.disable('disability_compensation_prevent_submission_job') # rubocop:disable Project/ForbidFlipperToggleInSpecs
        Flipper.disable('disability_compensation_production_tester') # rubocop:disable Project/ForbidFlipperToggleInSpecs
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
        allow_any_instance_of(User).to receive(:icn).and_return('123498767V234859')
      end

      let(:form526v2) do
        Rails.root.join('spec', 'support', 'disability_compensation_form', 'submit_all_claim', 'all.json').read
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
        Flipper.disable('disability_compensation_production_tester') # rubocop:disable Project/ForbidFlipperToggleInSpecs
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
      let(:user) do
        build(:user, middle_name: 'Lee', edipi: '1234567890', loa: { current: 3, highest: 3 })
      end
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      it 'supports getting user with some external errors', :skip_mvi do
        expect(subject).to validate(:get, '/v0/user', 296, headers)
      end

      it 'returns 296 when VAProfile returns an error', :skip_mvi do
        allow_any_instance_of(VAProfile::VeteranStatus::Service)
          .to receive(:get_veteran_status)
          .and_raise(StandardError.new('VAProfile error'))
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
      include_context 'with service account authentication', 'eventbus',
                      ['http://www.example.com/v0/event_bus_gateway/send_email',
                       'http://www.example.com/v0/event_bus_gateway/send_push',
                       'http://www.example.com/v0/event_bus_gateway/send_notifications'], { user_attributes: { participant_id: '1234' } }

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

      context 'when sending push notifications' do
        let(:params) do
          {
            template_id: '9999'
          }
        end

        it 'documents an unauthenticated request' do
          expect(subject).to validate(:post, '/v0/event_bus_gateway/send_push', 401)
        end

        it 'documents a success' do
          expect(subject).to validate(
            :post,
            '/v0/event_bus_gateway/send_push',
            200,
            '_headers' => service_account_auth_header,
            '_data' => params
          )
        end
      end

      context 'when sending notifications' do
        let(:params) do
          {
            email_template_id: '1111',
            push_template_id: '2222'
          }
        end

        it 'documents an unauthenticated request' do
          expect(subject).to validate(:post, '/v0/event_bus_gateway/send_notifications', 401)
        end

        it 'documents a success' do
          expect(subject).to validate(
            :post,
            '/v0/event_bus_gateway/send_notifications',
            200,
            '_headers' => service_account_auth_header,
            '_data' => params
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

    describe 'Direct Deposit' do
      let(:user) { create(:user, :loa3, icn: '1012666073V986297') }

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

    describe 'profiles', :initiate_vaprofile do
      let(:mhv_user) { build(:user, :loa3, idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }

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

        VCR.use_cassette('va_profile/v2/contact_information/post_email_success') do
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

        VCR.use_cassette('va_profile/v2/contact_information/post_telephone_success') do
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
        address = build(:va_profile_validation_address, :multiple_matches)
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
          address = build(:va_profile_address, id: 15_035)

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

        VCR.use_cassette('va_profile/v2/contact_information/put_address_success') do
          address = build(:va_profile_address, id: 15_035)

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
          address = build(:va_profile_address, id: 15_035)

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

    describe 'profile/status', :initiate_vaprofile do
      let(:mhv_user) { build(:user, :loa3, idme_uuid: '9021914d-d4ab-4c49-b297-ac8e8a792ed7') }

      before do
        sign_in_as(mhv_user)
      end

      it 'supports GETting async transaction by ID' do
        transaction = create(
          :va_profile_address_transaction,
          transaction_id: '0ea91332-4713-4008-bd57-40541ee8d4d4',
          user_uuid: mhv_user.uuid
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

    describe 'profile/person/status/:transaction_id' do
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

    describe 'profile/connected_applications' do
      let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
      let(:user) { create(:user, :loa3, :legacy_icn) }
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
        Flipper.disable(:search_use_v2_gsa) # rubocop:disable Project/ForbidFlipperToggleInSpecs
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
      let(:user) { build(:user, :loa3, icn: '1012667145V762142') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }
      let(:bad_headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

      before do
        allow(Flipper).to receive(:enabled?).with(:fetch_1095b_from_enrollment_system, any_args).and_return(true)
        Timecop.freeze(Time.zone.parse('2025-03-05T08:00:00Z'))
      end

      after { Timecop.return }

      context 'available forms' do
        it 'supports getting available forms' do
          VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_success',
                           { match_requests_on: %i[method uri] }) do
            expect(subject).to validate(
              :get,
              '/v0/form1095_bs/available_forms',
              200,
              headers
            )
          end
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

    describe 'dependents applications' do
      context 'default v2 form' do
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

    describe 'form 21-2680 house bound status' do
      let(:user) { create(:user) }
      let(:saved_claim) { create(:form212680) }
      let(:auth_headers) do
        {
          '_headers' => {
            'Cookie' => sign_in(user, nil, true),
            'Accept' => 'application/json',
            'Content-Type' => 'application/json'
          }
        }
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, anything).and_return(true)
      end

      it 'supports submitting a form 21-2680' do
        expect(subject).to validate(
          :post,
          '/v0/form212680',
          200,
          auth_headers.merge('_data' => { form: VetsJsonSchema::EXAMPLES['21-2680'].to_json }.to_json)
        )
      end

      it 'handles 400' do
        expect(subject).to validate(
          :post,
          '/v0/form212680',
          400,
          auth_headers.merge('_data' => { foo: :bar }.to_json)
        )
      end

      it 'handles 422' do
        expect(subject).to validate(
          :post,
          '/v0/form212680',
          422,
          auth_headers.merge('_data' => { form: { foo: :bar }.to_json }.to_json)
        )
      end

      it 'successfully downloads form212680 pdf', skip: 'swagger validation cannot handle binary PDF response' do
        expect(subject).to validate(
          :get,
          '/v0/form212680/download_pdf/{guid}',
          200,
          { '_headers' => { 'Cookie' => sign_in(user, nil, true) }, 'guid' => saved_claim.guid }
        )
      end

      it 'returns not found for bad guids' do
        expect(subject).to validate(
          :get,
          '/v0/form212680/download_pdf/{guid}',
          404,
          { '_headers' => { 'Cookie' => sign_in(user, nil, true) }, 'guid' => 'bad-guid' }
        )
      end

      context 'when feature toggle is disabled' do
        before { allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, anything).and_return(false) }

        it 'handles 404 for create' do
          expect(subject).to validate(
            :post,
            '/v0/form212680',
            404,
            auth_headers.merge('_data' => { form: VetsJsonSchema::EXAMPLES['21-2680'].to_json }.to_json)
          )
        end

        it 'handles 404 for download_pdf' do
          expect(subject).to validate(
            :get,
            '/v0/form212680/download_pdf/{guid}',
            404,
            { '_headers' => { 'Cookie' => sign_in(user, nil, true) }, 'guid' => saved_claim.guid }
          )
        end
      end
    end

    describe 'form 21-0779 nursing home information' do
      let(:saved_claim) { create(:va210779) }

      before do
        allow(Flipper).to receive(:enabled?).with(:form_0779_enabled, nil).and_return(true)
      end

      it 'supports submitting a form 21-0779' do
        expect(subject).to validate(
          :post,
          '/v0/form210779',
          200,
          json_headers.merge('_data' => { form: VetsJsonSchema::EXAMPLES['21-0779'].to_json }.to_json)
        )
      end

      it 'handles 422' do
        expect(subject).to validate(
          :post,
          '/v0/form210779',
          422,
          json_headers.merge('_data' => { form: { foo: :bar }.to_json }.to_json)
        )
      end

      it 'handles 400' do
        expect(subject).to validate(
          :post,
          '/v0/form210779',
          400,
          json_headers.merge('_data' => { foo: :bar }.to_json)
        )
      end

      it 'successfully downloads form210779 pdf', skip: 'swagger validation cannot handle binary PDF response' do
        expect(subject).to validate(
          :get,
          '/v0/form210779/download_pdf/{guid}',
          200,
          'guid' => saved_claim.guid
        )
      end

      it 'handles 404' do
        expect(subject).to validate(
          :get,
          '/v0/form210779/download_pdf/{guid}',
          404,
          'guid' => 'bad-id'
        )
      end

      context 'when feature toggle is disabled' do
        before { allow(Flipper).to receive(:enabled?).with(:form_0779_enabled, nil).and_return(false) }

        it 'supports submitting a form 21-0779' do
          expect(subject).to validate(
            :post,
            '/v0/form210779',
            404,
            json_headers.merge('_data' => { form: VetsJsonSchema::EXAMPLES['21-0779'].to_json }.to_json)
          )
        end

        it 'handles 404' do
          expect(subject).to validate(
            :get,
            '/v0/form210779/download_pdf/{guid}',
            404,
            'guid' => saved_claim.guid
          )
        end
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
        allow(Flipper).to receive(:enabled?)
          .with(:cst_claim_letters_use_lighthouse_api_provider, anything)
          .and_return(false)
        # Response comes from fixture: spec/fixtures/claim_letter/claim_letter_list.json
        expect(subject).to validate(:get, '/v0/claim_letters', 200, headers)
        expect(subject).to validate(:get, '/v0/claim_letters', 401)
      end
    end

    describe 'benefits claims' do
      let(:user) { create(:user, :loa3, :accountable, :legacy_icn, uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }
      let(:invalid_user) { create(:user, :loa3, :accountable, :legacy_icn, participant_id: nil) }
      let(:user_account) { create(:user_account, id: user.uuid) }
      let(:claim_id) { 600_383_363 }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }
      let(:invalid_headers) { { '_headers' => { 'Cookie' => sign_in(invalid_user, nil, true) } } }

      describe 'GET /v0/benefits_claims/{id}' do
        let(:headers_with_id) { headers.merge('id' => claim_id.to_s) }
        let(:invalid_headers_with_id) { invalid_headers.merge('id' => claim_id.to_s) }

        context 'when the user is not signed in' do
          it 'returns a status of 401' do
            expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 401, 'id' => claim_id.to_s)
          end
        end

        context 'when the user is signed in, but does not have valid credentials' do
          it 'returns a status of 403' do
            expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 403, invalid_headers_with_id)
          end
        end

        context 'when the user is signed in and has valid credentials' do
          before do
            token = 'fake_access_token'
            allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
          end

          context 'with cst_multi_claim_provider disabled' do
            before do
              allow(Flipper).to receive(:enabled?).with('cst_multi_claim_provider', anything).and_return(false)
            end

            context 'when there is a bad request' do
              it 'returns a status of 400' do
                allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
                  .and_raise(Common::Exceptions::BadRequest.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 400, headers_with_id)
              end
            end

            context 'when the claim is not found' do
              it 'returns a status of 404' do
                VCR.use_cassette('lighthouse/benefits_claims/show/404_response') do
                  expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 404, headers_with_id)
                end
              end
            end

            context 'when there is a rate limit exceeded' do
              it 'returns a status of 429' do
                allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
                  .and_raise(Common::Exceptions::TooManyRequests.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 429, headers_with_id)
              end
            end

            context 'when there is an internal server error' do
              it 'returns a status of 500' do
                allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
                  .and_raise(Common::Exceptions::ExternalServerInternalServerError.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 500, headers_with_id)
              end
            end

            context 'when there is a bad gateway error' do
              it 'returns a status of 502' do
                allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
                  .and_raise(Common::Exceptions::BadGateway.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 502, headers_with_id)
              end
            end

            context 'when there is a service unavailable' do
              it 'returns a status of 503' do
                allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
                  .and_raise(Common::Exceptions::ServiceUnavailable.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 503, headers_with_id)
              end
            end

            context 'when there is a gateway timeout' do
              it 'returns a status of 504' do
                allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claim)
                  .and_raise(Common::Exceptions::GatewayTimeout.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 504, headers_with_id)
              end
            end

            it 'returns a status of 200' do
              VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 200, headers_with_id)
              end
            end
          end

          context 'with cst_multi_claim_provider enabled' do
            before do
              allow(Flipper).to receive(:enabled?).with('cst_multi_claim_provider', anything).and_return(true)
            end

            context 'when there is a bad request' do
              it 'returns a status of 400' do
                allow_any_instance_of(V0::BenefitsClaimsController).to receive(:get_claim_from_providers)
                  .and_raise(Common::Exceptions::BadRequest.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 400, headers_with_id)
              end
            end

            context 'when there is a rate limit exceeded' do
              it 'returns a status of 429' do
                allow_any_instance_of(V0::BenefitsClaimsController).to receive(:get_claim_from_providers)
                  .and_raise(Common::Exceptions::TooManyRequests.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 429, headers_with_id)
              end
            end

            context 'when there is an internal server error' do
              it 'returns a status of 500' do
                allow_any_instance_of(V0::BenefitsClaimsController).to receive(:get_claim_from_providers)
                  .and_raise(Common::Exceptions::ExternalServerInternalServerError.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 500, headers_with_id)
              end
            end

            context 'when there is a bad gateway error' do
              it 'returns a status of 502' do
                allow_any_instance_of(V0::BenefitsClaimsController).to receive(:get_claim_from_providers)
                  .and_raise(Common::Exceptions::BadGateway.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 502, headers_with_id)
              end
            end

            context 'when there is a service unavailable' do
              it 'returns a status of 503' do
                allow_any_instance_of(V0::BenefitsClaimsController).to receive(:get_claim_from_providers)
                  .and_raise(Common::Exceptions::ServiceUnavailable.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 503, headers_with_id)
              end
            end

            context 'when there is a gateway timeout' do
              it 'returns a status of 504' do
                allow_any_instance_of(V0::BenefitsClaimsController).to receive(:get_claim_from_providers)
                  .and_raise(Common::Exceptions::GatewayTimeout.new)
                expect(subject).to validate(:get, '/v0/benefits_claims/{id}', 504, headers_with_id)
              end
            end
          end
        end
      end

      describe 'GET /v0/benefits_claims/failed_upload_evidence_submissions' do
        before do
          user.user_account_uuid = user_account.id
          user.save!
        end

        context 'when the user is not signed in' do
          it 'returns a status of 401' do
            expect(subject).to validate(:get, '/v0/benefits_claims/failed_upload_evidence_submissions', 401)
          end
        end

        context 'when the user is signed in, but does not have valid credentials' do
          it 'returns a status of 403' do
            expect(subject).to validate(:get, '/v0/benefits_claims/failed_upload_evidence_submissions', 403,
                                        invalid_headers)
          end
        end

        context 'when the user is signed in and has valid credentials' do
          before do
            token = 'fake_access_token'
            allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
            create(:bd_lh_evidence_submission_failed_type2_error, claim_id:, user_account:)
          end

          context 'when the ICN is not found' do
            it 'returns a status of 404' do
              VCR.use_cassette('lighthouse/benefits_claims/show/404_response') do
                expect(subject).to validate(:get, '/v0/benefits_claims/failed_upload_evidence_submissions', 404,
                                            headers)
              end
            end
          end

          context 'when there is a gateway timeout' do
            it 'returns a status of 504' do
              VCR.use_cassette('lighthouse/benefits_claims/show/504_response') do
                expect(subject).to validate(:get, '/v0/benefits_claims/failed_upload_evidence_submissions', 504,
                                            headers)
              end
            end
          end

          context 'when Lighthouse takes too long to respond' do
            it 'returns a status of 504' do
              allow_any_instance_of(BenefitsClaims::Configuration).to receive(:get).and_raise(Faraday::TimeoutError)
              expect(subject).to validate(:get, '/v0/benefits_claims/failed_upload_evidence_submissions', 504, headers)
            end
          end

          it 'returns a status of 200' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              expect(subject).to validate(:get, '/v0/benefits_claims/failed_upload_evidence_submissions', 200, headers)
            end
          end
        end
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

      before do
        allow(Flipper).to receive(:enabled?).with(:travel_pay_appt_add_v4_upgrade, instance_of(User)).and_return(false)
      end

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

  describe 'veteran_status_card' do
    let(:user) { create(:user, :loa3) }
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

    it 'returns ok status code' do
      status_card_response = {
        type: 'veteran_status_card',
        veteran_status: 'confirmed',
        service_summary_code: 'A1',
        not_confirmed_reason: 'MORE_RESEARCH_REQUIRED',
        attributes: {
          full_name: 'John Doe',
          disability_rating: 50,
          latest_service: {
            branch: 'Army',
            begin_date: '2010-01-01',
            end_date: '2015-12-31'
          },
          edipi: user.edipi
        }
      }
      allow_any_instance_of(VeteranStatusCard::Service).to receive(:status_card).and_return(status_card_response)
      expect(subject).to validate(:get, '/v0/veteran_status_card', 200, headers)
    end
  end

  describe 'scheduling preferences', :initiate_vaprofile do
    let(:mhv_user) { build(:user, :loa3, idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      sign_in_as(mhv_user)
      allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences, mhv_user).and_return(true)
      allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(true)

      service_response_mock = double(
        status: 200,
        person_options: [],
        bio: { personOptions: [] }
      )

      allow_any_instance_of(VAProfile::PersonSettings::Service).to receive(:get_person_options)
        .and_return(service_response_mock)
      allow_any_instance_of(VAProfile::PersonSettings::Service).to receive(:update_person_options)
        .and_return(double)

      transaction_mock = double(
        id: 'txn-123',
        transaction_id: 'txn-123',
        transaction_status: 'RECEIVED',
        type: 'AsyncTransaction::VAProfile::PersonOptionsTransaction'
      )

      allow(AsyncTransaction::VAProfile::PersonOptionsTransaction).to receive(:start)
        .and_return(transaction_mock)

      allow_any_instance_of(AsyncTransaction::BaseSerializer).to receive(:serializable_hash)
        .and_return({
                      data: {
                        id: 'txn-123',
                        type: 'async_transaction_va_profile_person_options_transactions',
                        attributes: {
                          transaction_id: 'txn-123',
                          transaction_status: 'RECEIVED',
                          type: 'AsyncTransaction::VAProfile::PersonOptionsTransaction',
                          metadata: []
                        }
                      }
                    })

      allow_any_instance_of(SchedulingPreferencesSerializer).to receive(:serializable_hash)
        .and_return({
                      data: {
                        id: '',
                        type: 'scheduling_preferences',
                        attributes: {
                          preferences: []
                        }
                      }
                    })
    end

    it 'supports getting scheduling preferences' do
      expect(subject).to validate(:get, '/v0/profile/scheduling_preferences', 401)
      expect(subject).to validate(:get, '/v0/profile/scheduling_preferences', 200, headers)
    end

    it 'supports getting scheduling preferences with 403 for non-pilot users' do
      allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(false)
      expect(subject).to validate(:get, '/v0/profile/scheduling_preferences', 403, headers)
    end

    it 'supports posting scheduling preferences' do
      expect(subject).to validate(:post, '/v0/profile/scheduling_preferences', 401)

      scheduling_preferences = { item_id: 1, option_ids: [5] }
      expect(subject).to validate(
        :post,
        '/v0/profile/scheduling_preferences',
        200,
        headers.merge('_data' => scheduling_preferences)
      )
    end

    it 'supports putting scheduling preferences' do
      expect(subject).to validate(:put, '/v0/profile/scheduling_preferences', 401)

      scheduling_preferences = { item_id: 1, option_ids: [7] }
      expect(subject).to validate(
        :put,
        '/v0/profile/scheduling_preferences',
        200,
        headers.merge('_data' => scheduling_preferences)
      )
    end

    it 'supports deleting scheduling preferences' do
      expect(subject).to validate(:delete, '/v0/profile/scheduling_preferences', 401)

      scheduling_preferences = { item_id: 1, option_ids: [5] }
      expect(subject).to validate(
        :delete,
        '/v0/profile/scheduling_preferences',
        200,
        headers.merge('_data' => scheduling_preferences)
      )
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
      subject.untested_mappings['/v0/form210779/download_pdf/{guid}']['get'].delete('200')
      subject.untested_mappings['/v0/form212680/download_pdf/{guid}']['get'].delete('200')
      subject.untested_mappings.delete('/v0/form0969')
      subject.untested_mappings.delete('/travel_pay/v0/claims/{claimId}/documents/{docId}')

      # SiS methods that involve forms & redirects
      subject.untested_mappings.delete('/v0/sign_in/authorize')
      subject.untested_mappings.delete('/v0/sign_in/callback')
      subject.untested_mappings.delete('/v0/sign_in/logout')

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
