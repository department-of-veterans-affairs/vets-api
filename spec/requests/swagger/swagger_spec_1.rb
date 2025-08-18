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

RSpec.describe 'API doc validations (Part 1)', type: :request do
  context 'json validation' do
    it 'has valid json' do
      get '/v0/apidocs.json'
      json = response.body
      JSON.parse(json).to_yaml
    end
  end
end

RSpec.describe 'the v0 API documentation (Part 1)', order: :defined, type: %i[apivore request] do
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
  end
end