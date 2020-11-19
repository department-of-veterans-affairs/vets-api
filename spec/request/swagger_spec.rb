# frozen_string_literal: true

require 'rails_helper'

require 'support/bb_client_helpers'
require 'support/pagerduty/services/spec_setup'
require 'support/stub_debt_letters'
require 'support/stub_efolder_documents'
require 'support/sm_client_helpers'
require 'support/rx_client_helpers'

RSpec.describe 'API doc validations', type: :request do
  context 'json validation' do
    it 'has valid json' do
      get '/v0/apidocs.json'
      json = response.body
      JSON.parse(json).to_yaml
    end
  end
end

RSpec.describe 'the API documentation', type: %i[apivore request], order: :defined do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:rubysaml_settings) { build(:rubysaml_settings) }
  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  before do
    create(:account, idme_uuid: mhv_user.uuid)
    allow(SAML::SettingsService).to receive(:saml_settings).and_return(rubysaml_settings)
  end

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    describe 'backend statuses' do
      describe '/v0/backend_statuses/{service}' do
        it 'supports getting backend service status' do
          expect(subject).to validate(:get, '/v0/backend_statuses/{service}', 200, headers.merge('service' => 'gibs'))
        end
      end

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
      FactoryBot.create(:in_progress_form, user_uuid: mhv_user.uuid)
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
      form = FactoryBot.create(:in_progress_form, user_uuid: mhv_user.uuid)
      expect(subject).to validate(
        :delete,
        '/v0/in_progress_forms/{id}',
        200,
        headers.merge('id' => form.form_id)
      )
      expect(subject).to validate(:delete, '/v0/in_progress_forms/{id}', 401, 'id' => form.form_id)
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

    it 'supports adding an caregiver\'s assistance claim' do
      VCR.use_cassette 'mpi/find_candidate/valid' do
        VCR.use_cassette 'emis/get_veteran_status/valid' do
          VCR.use_cassette 'carma/auth/token/200' do
            VCR.use_cassette 'carma/submissions/create/201' do
              VCR.use_cassette 'carma/attachments/upload/201' do
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
            end
          end
        end
      end

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

    it 'supports adding a pension' do
      expect(subject).to validate(
        :post,
        '/v0/pension_claims',
        200,
        '_data' => {
          'pension_claim' => {
            'form' => build(:pension_claim).form
          }
        }
      )

      expect(subject).to validate(
        :post,
        '/v0/pension_claims',
        422,
        '_data' => {
          'pension_claim' => {
            'invalid-form' => { invalid: true }.to_json
          }
        }
      )
    end

    it 'supports adding a burial claim', run_at: 'Thu, 29 Aug 2019 17:45:03 GMT' do
      allow(SecureRandom).to receive(:uuid).and_return('c3fa0769-70cb-419a-b3a6-d2563e7b8502')

      VCR.use_cassette(
        'mpi/find_candidate/find_profile_with_attributes',
        VCR::MATCH_EVERYTHING
      ) do
        expect(subject).to validate(
          :post,
          '/v0/burial_claims',
          200,
          '_data' => {
            'burial_claim' => {
              'form' => build(:burial_claim).form
            }
          }
        )

        expect(subject).to validate(
          :post,
          '/v0/burial_claims',
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

    it 'supports adding a preneed claim' do
      VCR.use_cassette('preneeds/burial_forms/creates_a_pre_need_burial_form') do
        expect(subject).to validate(
          :post,
          '/v0/preneeds/burial_forms',
          200,
          '_headers' => { 'content-type' => 'application/json' },
          '_data' => {
            'application' => attributes_for(:burial_form)
          }.to_json
        )
      end

      expect(subject).to validate(
        :post,
        '/v0/preneeds/burial_forms',
        422,
        '_data' => {
          'application' => {
            'invalid-form' => { invalid: true }.to_json
          }
        }
      )
    end

    describe 'preneed attachments upload' do
      it 'supports uploading a file' do
        expect(subject).to validate(
          :post,
          '/v0/preneeds/preneed_attachments',
          200,
          '_data' => {
            'preneed_attachment' => {
              'file_data' => fixture_file_upload('spec/fixtures/preneeds/extras.pdf', 'application/pdf')
            }
          }
        )
      end

      it 'returns a 400 if no attachment data is given' do
        expect(subject).to validate(
          :post,
          '/v0/preneeds/preneed_attachments',
          400,
          ''
        )
      end

      it 'returns 422 if the attachment is not an allowed type' do
        expect(subject).to validate(
          :post,
          '/v0/preneeds/preneed_attachments',
          422,
          '_data' => {
            'preneed_attachment' => {
              'file_data' => fixture_file_upload('spec/fixtures/files/invalid_idme_cert.crt')
            }
          }
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
    end

    context 'eFolder tests' do
      let(:user) { build(:user, :loa3) }
      let(:headers) do
        { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }
      end

      context 'efolder index' do
        stub_efolder_documents(:index)

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
        stub_efolder_documents(:show)

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

    context 'HCA tests' do
      let(:login_required) { Notification::LOGIN_REQUIRED }
      let(:test_veteran) do
        json_string = File.read(
          Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json')
        )
        json = JSON.parse(json_string)
        json.delete('email')
        json.to_json
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
              file_data: fixture_file_upload('spec/fixtures/files/invalid_idme_cert.crt')
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
      end

      let(:form526v2) do
        File.read(
          Rails.root.join('spec', 'support', 'disability_compensation_form', 'all_claims_fe_submission.json')
        )
      end

      it 'supports getting rated disabilities' do
        expect(subject).to validate(:get, '/v0/disability_compensation_form/rated_disabilities', 401)
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rated_disabilities', 200, headers)
        end
      end

      context 'with a loa1 user' do
        let(:mhv_user) { build(:user, :loa1) }

        it 'supports getting separation_locations' do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/separation_locations', 403, headers)
        end
      end

      it 'supports getting separation_locations' do
        expect(subject).to validate(:get, '/v0/disability_compensation_form/separation_locations', 401)
        VCR.use_cassette('evss/reference_data/get_intake_sites') do
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
        VCR.use_cassette('evss/ppiu/payment_information') do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            VCR.use_cassette('emis/get_military_service_episodes/valid', allow_playback_repeats: true) do
              VCR.use_cassette('evss/disability_compensation_form/submit_form_v2') do
                expect(subject).to validate(
                  :post,
                  '/v0/disability_compensation_form/submit_all_claim',
                  200,
                  headers.update(
                    '_data' => form526v2
                  )
                )
              end
            end
          end
        end
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
            200,
            headers.merge('job_id' => job_status.job_id)
          )
        end
      end

      it 'supports getting rating info' do
        expect(subject).to validate(:get, '/v0/disability_compensation_form/rating_info', 401)
        VCR.use_cassette('evss/disability_compensation_form/rating_info') do
          expect(subject).to validate(:get, '/v0/disability_compensation_form/rating_info', 200, headers)
        end
      end
    end

    describe 'intent to file' do
      it 'supports getting all intent to file' do
        expect(subject).to validate(:get, '/v0/intent_to_file', 401)
        VCR.use_cassette('evss/intent_to_file/intent_to_file') do
          expect(subject).to validate(:get, '/v0/intent_to_file', 200, headers)
        end
      end

      it 'supports getting an active compensation intent to file' do
        expect(subject).to validate(:get, '/v0/intent_to_file/{type}/active', 401, 'type' => 'compensation')
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          expect(subject).to validate(
            :get,
            '/v0/intent_to_file/{type}/active',
            200,
            headers.update('type' => 'compensation')
          )
        end
      end

      it 'supports creating an active compensation intent to file' do
        expect(subject).to validate(:post, '/v0/intent_to_file/{type}', 401, 'type' => 'compensation')
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
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
              expect(subject).to validate(:post, '/v0/mvi_users/{id}', 200, headers.merge('id' => '21-0966'))
            end
          end
        end
      end

      it 'fails when no user information is passed' do
        expect(subject).to validate(:post, '/v0/mvi_users/{id}', 401, 'id' => '21-0966')
      end
      context 'when user is missing birls only' do
        let(:mhv_user) { build(:user_with_no_birls_id) }

        it 'fails with 422' do
          expect(subject).to validate(:post, '/v0/mvi_users/{id}', 422, headers.merge('id' => '21-0966'))
        end
      end
    end

    describe 'PPIU' do
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
          '_data' => {
            'supporting_evidence_attachment' => {
              'file_data' => fixture_file_upload('spec/fixtures/pdf_fill/extras.pdf')
            }
          }
        )
      end

      it 'returns a 400 if no attachment data is given' do
        expect(subject).to validate(
          :post,
          '/v0/upload_supporting_evidence',
          400,
          ''
        )
      end

      it 'returns a 422 if a file is corrupted or invalid' do
        expect(subject).to validate(
          :post,
          '/v0/upload_supporting_evidence',
          422,
          '_data' => {
            'supporting_evidence_attachment' => {
              'file_data' => fixture_file_upload('spec/fixtures/files/malformed-pdf.pdf')
            }
          }
        )
      end
    end

    describe 'secure messaging' do
      include SM::ClientHelpers

      let(:uploads) do
        [
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file2.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file3.jpg', 'image/jpg'),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file4.jpg', 'image/jpg')
        ]
      end

      before do
        allow(SM::Client).to receive(:new).and_return(authenticated_client)
      end

      let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

      describe 'triage teams' do
        context 'successful calls' do
          it 'supports getting a list of all prescriptions' do
            VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
              expect(subject).to validate(:get, '/v0/messaging/health/recipients', 200, headers)
            end
          end
        end
      end

      describe 'folders' do
        context 'successful calls' do
          it 'supports getting a list of all folders' do
            VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders', 200, headers)
            end
          end

          it 'supports getting a list of all messages in a folder' do
            VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
              expect(subject).to validate(
                :get,
                '/v0/messaging/health/folders/{folder_id}/messages', 200, headers.merge('folder_id' => '0')
              )
            end
          end

          it 'supports getting information about a specific folder' do
            VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders/{id}', 200,
                                          headers.merge('id' => '0'))
            end
          end

          it 'supports creating a new folder' do
            VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
              expect(subject).to validate(:post, '/v0/messaging/health/folders', 201,
                                          headers.merge(
                                            '_data' => { 'folder' => { 'name' => 'test folder 66745' } }
                                          ))
            end
          end

          it 'supports deleting a folder' do
            VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
              expect(subject).to validate(:delete, '/v0/messaging/health/folders/{id}', 204,
                                          headers.merge('id' => '674886'))
            end
          end
        end

        context 'unsuccessful calls' do
          it 'supports get a single folder id error messages' do
            VCR.use_cassette('sm_client/folders/gets_a_single_folder_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/folders/{id}', 404,
                                          headers.merge('id' => '1000'))
            end
          end

          it 'supports deletea folder id folder error messages' do
            VCR.use_cassette('sm_client/folders/deletes_a_folder_id_error') do
              expect(subject).to validate(:delete, '/v0/messaging/health/folders/{id}', 404,
                                          headers.merge('id' => '1000'))
            end
          end

          it 'supports folder messages index error in a folder' do
            VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages_id_error') do
              expect(subject).to validate(
                :get,
                '/v0/messaging/health/folders/{folder_id}/messages', 404, headers.merge('folder_id' => '1000')
              )
            end
          end
        end
      end

      describe 'messages' do
        context 'successful calls' do
          it 'supports getting a list of all messages in a thread' do
            VCR.use_cassette('sm_client/messages/gets_a_message_thread') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}/thread', 200,
                                          headers.merge('id' => '573059'))
            end
          end

          it 'supports getting a message' do
            VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}', 200,
                                          headers.merge('id' => '573059'))
            end
          end

          it 'supports getting a list of message categories' do
            VCR.use_cassette('sm_client/messages/gets_message_categories') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/categories', 200, headers)
            end
          end

          it 'supports getting message attachments' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          200, headers.merge('message_id' => '629999', 'id' => '629993'))
            end
          end

          it 'supports moving a message to another folder' do
            VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
              expect(subject).to validate(:patch, '/v0/messaging/health/messages/{id}/move',
                                          204, headers.merge('id' => '573052', '_query_string' => 'folder_id=0'))
            end
          end

          it 'supports creating a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 200,
                headers.merge('_data' => { 'message' => {
                                'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                                'body' => 'Continuous Integration'
                              } })
              )
            end
          end

          it 'supports creating a message with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 200,
                headers.merge('id' => '674838',
                              '_data' => {
                                'message' => {
                                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                                  'body' => 'Continuous Integration'
                                },
                                'uploads' => uploads
                              })
              )
            end
          end

          it 'supports replying to a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 201,
                headers.merge('id' => '674838',
                              '_data' => { 'message' => {
                                'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                                'body' => 'Continuous Integration'
                              } })
              )
            end
          end

          it 'supports replying to a message with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 201,
                headers.merge('id' => '674838',
                              '_data' => {
                                'message' => {
                                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                                  'body' => 'Continuous Integration'
                                },
                                'uploads' => uploads
                              })
              )
            end
          end

          it 'supports deleting a message' do
            VCR.use_cassette('sm_client/messages/deletes_the_message_with_id') do
              expect(subject).to validate(:delete, '/v0/messaging/health/messages/{id}', 204,
                                          headers.merge('id' => '573052'))
            end
          end
        end

        context 'unsuccessful calls' do
          it 'supports errors for list of all messages in a thread with invalid id' do
            VCR.use_cassette('sm_client/messages/gets_a_message_thread_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}/thread', 404,
                                          headers.merge('id' => '999999'))
            end
          end

          it 'supports error message with invalid id' do
            VCR.use_cassette('sm_client/messages/gets_a_message_with_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{id}', 404,
                                          headers.merge('id' => '999999'))
            end
          end

          it 'supports errors getting message attachments with invalid message id' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment_message_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          404, headers.merge('message_id' => '999999', 'id' => '629993'))
            end
          end

          it 'supports errors getting message attachments with invalid attachment id' do
            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_file_attachment_attachment_id_error') do
              expect(subject).to validate(:get, '/v0/messaging/health/messages/{message_id}/attachments/{id}',
                                          404, headers.merge('message_id' => '629999', 'id' => '999999'))
            end
          end

          it 'supports errors moving a message to another folder' do
            VCR.use_cassette('sm_client/messages/moves_a_message_with_id_error') do
              expect(subject).to validate(:patch, '/v0/messaging/health/messages/{id}/move',
                                          404, headers.merge('id' => '999999', '_query_string' => 'folder_id=0'))
            end
          end

          it 'supports errors creating a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments_recipient_id_error') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages', 422,
                headers.merge('_data' => { 'message' => {
                                'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '1',
                                'body' => 'Continuous Integration'
                              } })
              )
            end
          end

          it 'supports errors replying to a message with no attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments_id_error') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/messages/{id}/reply', 404,
                headers.merge('id' => '999999',
                              '_data' => { 'message' => {
                                'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                                'body' => 'Continuous Integration'
                              } })
              )
            end
          end

          it 'supports errors deleting a message' do
            VCR.use_cassette('sm_client/messages/deletes_the_message_with_id_error') do
              expect(subject).to validate(:delete, '/v0/messaging/health/messages/{id}', 404,
                                          headers.merge('id' => '999999'))
            end
          end
        end
      end

      describe 'message drafts' do
        context 'successful calls' do
          it 'supports creating a message draft' do
            VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/message_drafts', 201,
                headers.merge('_data' => { 'message_draft' => {
                                'subject' => 'Subject 1', 'category' => 'OTHER', 'recipient_id' => '613586',
                                'body' => 'Body 1'
                              } })
              )
            end
          end

          %i[put patch].each do |op|
            it "supports updating a message draft with #{op}" do
              VCR.use_cassette('sm_client/message_drafts/updates_a_draft') do
                expect(subject).to validate(
                  op, '/v0/messaging/health/message_drafts/{id}', 204,
                  headers.merge('id' => '674942',
                                '_data' => { 'message_draft' => {
                                  'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                                  'body' => 'Updated Body'
                                } })
                )
              end
            end
          end

          it 'supports creating a message draft reply' do
            VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
              expect(subject).to validate(
                :post, '/v0/messaging/health/message_drafts/{reply_id}/replydraft', 201,
                headers.merge('reply_id' => '674874',
                              '_data' => { 'message_draft' => {
                                'subject' => 'Updated Subject', 'category' => 'OTHER', 'recipient_id' => '613586',
                                'body' => 'Body 1'
                              } })
              )
            end
          end

          it 'supports updating a message draft reply' do
            VCR.use_cassette('sm_client/message_drafts/updates_a_draft_reply') do
              expect(subject).to validate(
                :put, '/v0/messaging/health/message_drafts/{reply_id}/replydraft/{draft_id}', 204,
                headers.merge('reply_id' => '674874',
                              'draft_id' => '674944',
                              '_data' => { 'message_draft' => {
                                'subject' => 'CI Run', 'category' => 'OTHER', 'recipient_id' => '613586',
                                'body' => 'Updated Body'
                              } })
              )
            end
          end
        end
      end
    end

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
              # Using mucked-up yml because apivore has a problem processing non-json responses
              VCR.use_cassette('bb_client/gets_a_text_report_for_apivore') do
                expect(subject).to validate(:get, '/v0/health_records', 200,
                                            headers.merge('_query_string' => 'doc_type=txt'))
              end
            end
          end

          context 'unsuccessful calls' do
            it 'handles a backend error' do
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
            VCR.use_cassette('bb_client/gets_a_list_of_eligible_data_classes') do
              expect(subject).to validate(:get, '/v0/health_records/eligible_data_classes', 200, headers)
            end
          end
        end

        describe 'refresh' do
          context 'successful calls' do
            it 'supports health records refresh' do
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

    context 'without EVSS mock' do
      before do
        Settings.evss.mock_gi_bill_status = false
        Settings.evss.mock_letters = false
      end

      it 'supports getting EVSS Gi Bill Status' do
        Timecop.freeze(ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').parse('1st Feb 2018 12:15:06'))
        expect(subject).to validate(:get, '/v0/post911_gi_bill_status', 401)
        VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
          # TODO: this cassette was hacked to return all 3 entitlements since
          # I cannot make swagger doc allow an attr to be :object or :null
          expect(subject).to validate(:get, '/v0/post911_gi_bill_status', 200, headers)
        end
        VCR.use_cassette('evss/gi_bill_status/vet_not_found') do
          expect(subject).to validate(:get, '/v0/post911_gi_bill_status', 404, headers)
        end
        Timecop.return
      end

      it 'supports Gi Bill Status 503 condition' do
        # Timecop.freeze(Time.zone.parse('1st Feb 2018 00:15:06'))
        Timecop.freeze(ActiveSupport::TimeZone.new('Eastern Time (US & Canada)').parse('1st Feb 2018 00:15:06'))
        expect(subject).to validate(:get, '/v0/post911_gi_bill_status', 503, headers)
        Timecop.return
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

      it 'supports getting EVSS PCIUAddress states' do
        expect(subject).to validate(:get, '/v0/address/states', 401)
        VCR.use_cassette('evss/pciu_address/states') do
          expect(subject).to validate(:get, '/v0/address/states', 200, headers)
        end
      end

      it 'supports getting EVSS PCIUAddress countries' do
        expect(subject).to validate(:get, '/v0/address/countries', 401)
        VCR.use_cassette('evss/pciu_address/countries') do
          expect(subject).to validate(:get, '/v0/address/countries', 200, headers)
        end
      end

      it 'supports getting EVSS PCIUAddress' do
        expect(subject).to validate(:get, '/v0/address', 401)
        VCR.use_cassette('evss/pciu_address/address_domestic') do
          expect(subject).to validate(:get, '/v0/address', 200, headers)
        end
      end

      it 'supports putting EVSS PCIUAddress' do
        expect(subject).to validate(:put, '/v0/address', 401)
        VCR.use_cassette('evss/pciu_address/address_update') do
          expect(subject).to validate(
            :put,
            '/v0/address',
            200,
            headers.update(
              '_data' => {
                'type' => 'DOMESTIC',
                'address_effective_date' => '2017-08-07T19:43:59.383Z',
                'address_one' => '225 5th St',
                'address_two' => '',
                'address_three' => '',
                'city' => 'Springfield',
                'state_code' => 'OR',
                'country_name' => 'USA',
                'zip_code' => '97477',
                'zip_suffix' => ''
              }
            )
          )
        end
      end
    end

    it 'supports getting the user data' do
      expect(subject).to validate(:get, '/v0/user', 200, headers)
      expect(subject).to validate(:get, '/v0/user', 401)
    end

    context '/v0/user endpoint with some external service errors' do
      let(:user) { build(:user, middle_name: 'Lee') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      it 'supports getting user with some external errors', skip_mvi: true do
        expect(subject).to validate(:get, '/v0/user', 296, headers)
      end
    end

    context 'terms and conditions routes' do
      context 'with some terms and acceptances' do
        let!(:terms) { create(:terms_and_conditions, latest: true) }
        # The Faker in the factory will _sometimes_ return the same name. make sure it's different
        # so that the association in terms_acc works as expected with these tests.
        let!(:terms2) { create(:terms_and_conditions, latest: true, name: "#{terms.name}-again") }
        let!(:terms_acc) do
          create(:terms_and_conditions_acceptance, user_uuid: mhv_user.uuid, terms_and_conditions: terms)
        end

        it 'validates the routes' do
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions',
            200
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest',
            200,
            'name' => terms.name
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            200,
            headers.merge('name' => terms.name)
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            422,
            headers.merge('name' => terms.name)
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            200,
            headers.merge('name' => terms2.name)
          )
        end

        it 'validates auth errors' do
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            401,
            'name' => terms.name
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            401,
            'name' => terms.name
          )
        end
      end

      context 'with no terms and acceptances' do
        it 'validates the routes' do
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions',
            200
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest',
            404,
            'name' => 'blat'
          )
          expect(subject).to validate(
            :get,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            404,
            headers.merge('name' => 'blat')
          )
          expect(subject).to validate(
            :post,
            '/v0/terms_and_conditions/{name}/versions/latest/user_data',
            404,
            headers.merge('name' => 'blat')
          )
        end
      end
    end

    describe 'facility locator tests', team: :facilities do
      context 'successful calls' do
        let(:provider) { FactoryBot.build(:provider, :from_provider_info) }
        let(:provider_services_response) do
          {
            'CareSiteAddressStreet' => '3195 S Price Rd Ste 148',
            'CareSiteAddressCity' => 'Chandler',
            'CareSiteAddressZipCode' => '85248',
            'CareSiteAddressState' => 'AZ',
            'Latitude' => 33.258135,
            'Longitude' => -111.887927
          }
        end

        vcr_options = {
          cassette_name: '/lighthouse/facilities',
          match_requests_on: %i[path query],
          allow_playback_repeats: true,
          record: :new_episodes
        }

        context 'Using the Lighthouse API', vcr: vcr_options do
          before do
            Flipper.enable(:facility_locator_lighthouse_api, true)
          end

          it 'supports getting a list of facilities' do
            expect(subject).to validate(
              :get,
              '/v0/facilities/va', 200,
              {
                '_query_string' => { bbox: ['-122.440689', '45.451913', '-122.78675', '45.64'] }.to_query
              }
            )
          end

          it '404s on non-existent facility' do
            expect(subject).to validate(:get, '/v0/facilities/va/{id}', 404, 'id' => 'nca_9999999')
          end
        end

        context 'Using Active Record' do
          before do
            Flipper.enable(:facility_locator_lighthouse_api, false)
          end

          it 'supports getting a list of facilities' do
            VCR.use_cassette('facilities/va/pdx_bbox') do
              expect(subject).to validate(:get, '/v0/facilities/va', 200,
                                          'bbox' => ['-122.440689', '45.451913', '-122.78675', '45.64'])
            end
          end

          it '404s on non-existent facility' do
            VCR.use_cassette('facilities/va/nonexistent_cemetery') do
              expect(subject).to validate(:get, '/v0/facilities/va/{id}', 404, 'id' => 'nca_9999999')
            end
          end
        end

        it 'supports getting a single facility' do
          VCR.use_cassette('/lighthouse/facilities', match_requests_on: %i[path query]) do
            create :vha_648A4
            expect(subject).to validate(:get, '/v0/facilities/va/{id}', 200, 'id' => 'vha_648A4')
          end
        end

        it '400s on invalid bounding box query' do
          expect(subject).to validate(:get, '/v0/facilities/va', 400,
                                      '_query_string' => 'bbox[]=-122&bbox[]=45&bbox[]=-123')
        end

        it 'supports getting a list of facilities by name' do
          create :vha_648A4
          expect(subject).to validate(:get, '/v0/facilities/suggested', 200,
                                      '_query_string' => 'type[]=health&name_part=por')
        end

        it '400s on invalid type' do
          create :vha_648A4
          expect(subject).to validate(:get, '/v0/facilities/suggested', 400,
                                      '_query_string' => 'type[]=foo&name_part=por')
        end

        it 'supports getting a provider by id' do
          expect_any_instance_of(Facilities::PPMS::V0::Client).to receive(:provider_info)
            .with('1407842941').and_return(provider)
          expect_any_instance_of(Facilities::PPMS::V0::Client).to receive(:provider_services)
            .with('1407842941').and_return([provider_services_response])
          expect(subject).to validate(:get, '/v0/facilities/ccp/{id}', 200, 'id' => 'ccp_1407842941')
        end

        it '400s on improper id' do
          VCR.use_cassette('facilities/ppms/ppms', match_requests_on: %i[path query]) do
            expect(subject).to validate(:get, '/v0/facilities/ccp/{id}', 400, 'id' => 'ccap_123123')
          end
        end

        it '404s if provider is missing' do
          VCR.use_cassette('facilities/ppms/ppms_nonexistent', match_requests_on: [:method]) do
            expect(subject).to validate(:get, '/v0/facilities/ccp/{id}', 404, 'id' => 'ccp_123123')
          end
        end

        it 'supports getting the services list' do
          VCR.use_cassette('facilities/ppms/ppms_specialties', match_requests_on: %i[path query]) do
            expect(subject).to validate(:get, '/v0/facilities/services', 200)
          end
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

    describe 'higher_level_reviews' do
      context 'GET' do
        it 'documents higher_level_reviews 200' do
          VCR.use_cassette('decision_review/HLR-SHOW-RESPONSE-200') do
            expect(subject).to validate(:get, '/v0/higher_level_reviews/{uuid}',
                                        200, headers.merge('uuid' => '75f5735b-c41d-499c-8ae2-ab2740180254'))
          end
        end

        it 'documents higher_level_reviews 404' do
          VCR.use_cassette('decision_review/HLR-SHOW-RESPONSE-404') do
            expect(subject).to validate(:get, '/v0/higher_level_reviews/{uuid}',
                                        404, headers.merge('uuid' => '0'))
          end
        end
      end

      context 'POST' do
        it 'documents higher_level_reviews 200' do
          VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-200') do
            # HigherLevelReviewsController is a pass-through, and uses request.body directly (not params[]).
            # The validate helper does not create a parsable request.body string that works with the controller.
            allow_any_instance_of(V0::HigherLevelReviewsController).to receive(:request_body_hash).and_return(
              VetsJsonSchema::EXAMPLES.fetch('HLR-CREATE-REQUEST-BODY')
            )
            expect(subject).to validate(:post, '/v0/higher_level_reviews', 200, headers)
          end
        end

        it 'documents higher_level_reviews 422' do
          VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-422') do
            expect(subject).to validate(
              :post,
              '/v0/higher_level_reviews',
              422,
              headers.merge('_data' => { '_json' => '' })
            )
          end
        end
      end
    end

    describe 'contestable_issues' do
      let(:benefit_type) { 'compensation' }
      let(:ssn) { '212222112' }
      let(:receipt_date) { '2020-09-02' }
      let(:status) { 200 }

      it 'documents contestable_issues 200' do
        VCR.use_cassette("decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-#{status}") do
          expect(subject).to validate(
            :get,
            '/v0/higher_level_reviews/contestable_issues/{benefit_type}',
            status,
            headers.merge('benefit_type' => benefit_type)
          )
        end
      end

      context '404' do
        let(:ssn) { '000000000' }
        let(:status) { 404 }

        it 'documents contestable_issues 404' do
          VCR.use_cassette("decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-#{status}") do
            expect(subject).to validate(
              :get,
              '/v0/higher_level_reviews/contestable_issues/{benefit_type}',
              status,
              headers.merge('benefit_type' => benefit_type)
            )
          end
        end
      end

      context '422' do
        let(:benefit_type) { 'apricot' }
        let(:status) { 422 }

        it 'documents contestable_issues 422' do
          VCR.use_cassette("decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-#{status}") do
            expect(subject).to validate(
              :get,
              '/v0/higher_level_reviews/contestable_issues/{benefit_type}',
              status,
              headers.merge('benefit_type' => benefit_type)
            )
          end
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

    describe 'preferences' do
      let(:preference) { create(:preference) }
      let(:route) { '/v0/user/preferences/choices' }
      let(:choice) { create :preference_choice, preference: preference }
      let(:request_body) do
        [
          {
            preference: { code: preference.code },
            user_preferences: [{ code: choice.code }]
          }
        ]
      end

      it 'supports getting preference data' do
        expect(subject).to validate(:get, route, 200, headers)
        expect(subject).to validate(:get, route, 401)
        expect(subject).to validate(:get, "#{route}/{code}", 200, headers.merge('code' => preference.code))
        expect(subject).to validate(:get, "#{route}/{code}", 401, 'code' => preference.code)
        expect(subject).to validate(:get, "#{route}/{code}", 404, headers.merge('code' => 'wrong'))
      end

      it 'supports creating and/or updating UserPreferences for POST /v0/user/preferences' do
        expect(subject).to validate(
          :post,
          '/v0/user/preferences',
          200,
          headers.merge('_data' => { '_json' => request_body.as_json })
        )
      end

      it 'supports authorization validation for POST /v0/user/preferences' do
        expect(subject).to validate(:post, '/v0/user/preferences', 401)
      end

      it 'supports 400 error reporting for POST /v0/user/preferences' do
        bad_request_body = [
          {
            preference: { code: preference.code },
            user_preferences: []
          }
        ]

        expect(subject).to validate(
          :post,
          '/v0/user/preferences',
          400,
          headers.merge('_data' => { '_json' => bad_request_body.as_json })
        )
      end

      it 'supports 404 error reporting for POST /v0/user/preferences' do
        bad_request_body = [
          {
            preference: { code: 'code-not-in-db' },
            user_preferences: [{ code: 'code-not-in-db' }]
          }
        ]

        expect(subject).to validate(
          :post,
          '/v0/user/preferences',
          404,
          headers.merge('_data' => { '_json' => bad_request_body.as_json })
        )
      end

      it 'supports 422 error reporting for POST /v0/user/preferences' do
        allow(UserPreference).to receive(:for_preference_and_account).and_raise(
          ActiveRecord::RecordNotDestroyed.new('Cannot destroy this record')
        )

        expect(subject).to validate(
          :post,
          '/v0/user/preferences',
          422,
          headers.merge('_data' => { '_json' => request_body.as_json })
        )
      end
    end

    describe 'user preferences' do
      let(:benefits) { create(:preference, :benefits) }
      let(:account) { Account.first }

      before do
        create(
          :user_preference,
          account_id: account.id,
          preference: benefits,
          preference_choice: benefits.choices.first
        )
      end

      it 'supports getting an index of a user\'s UserPreferences' do
        expect(subject).to validate(:get, '/v0/user/preferences', 200, headers)
        expect(subject).to validate(:get, '/v0/user/preferences', 401)
      end

      it 'supports deleting all of a user\'s UserPreferences' do
        expect(subject).to validate(
          :delete,
          '/v0/user/preferences/{code}/delete_all',
          200,
          headers.merge('code' => benefits.code)
        )
        expect(subject).to validate(:delete, '/v0/user/preferences/{code}/delete_all', 401, 'code' => benefits.code)
        expect(subject).to validate(
          :delete,
          '/v0/user/preferences/{code}/delete_all',
          404,
          headers.merge('code' => 'junk')
        )

        allow(UserPreference).to receive(:for_preference_and_account).and_raise(
          ActiveRecord::RecordNotDestroyed.new('Cannot destroy this record')
        )
        expect(subject).to validate(
          :delete,
          '/v0/user/preferences/{code}/delete_all',
          422,
          headers.merge('code' => benefits.code)
        )
      end
    end

    describe 'profiles' do
      it 'supports getting email address data' do
        expect(subject).to validate(:get, '/v0/profile/email', 401)
        VCR.use_cassette('evss/pciu/email') do
          expect(subject).to validate(:get, '/v0/profile/email', 200, headers)
        end
      end

      it 'supports getting primary phone number data' do
        expect(subject).to validate(:get, '/v0/profile/primary_phone', 401)
        VCR.use_cassette('evss/pciu/primary_phone') do
          expect(subject).to validate(:get, '/v0/profile/primary_phone', 200, headers)
        end
      end

      it 'supports getting alternate phone number data' do
        expect(subject).to validate(:get, '/v0/profile/alternate_phone', 401)
        VCR.use_cassette('evss/pciu/alternate_phone') do
          expect(subject).to validate(:get, '/v0/profile/alternate_phone', 200, headers)
        end
      end

      it 'supports getting service history data' do
        expect(subject).to validate(:get, '/v0/profile/service_history', 401)
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          expect(subject).to validate(:get, '/v0/profile/service_history', 200, headers)
        end
      end

      it 'supports getting personal information data' do
        expect(subject).to validate(:get, '/v0/profile/personal_information', 401)
        VCR.use_cassette('mpi/find_candidate/valid') do
          expect(subject).to validate(:get, '/v0/profile/personal_information', 200, headers)
        end
      end

      it 'supports posting primary phone number data' do
        expect(subject).to validate(:post, '/v0/profile/primary_phone', 401)

        VCR.use_cassette('evss/pciu/post_primary_phone') do
          phone = build(:phone_number, :nil_effective_date)

          expect(subject).to validate(
            :post,
            '/v0/profile/primary_phone',
            200,
            headers.merge('_data' => phone.as_json)
          )
        end
      end

      it 'supports posting alternate phone number data' do
        expect(subject).to validate(:post, '/v0/profile/alternate_phone', 401)

        VCR.use_cassette('evss/pciu/post_alternate_phone') do
          phone = build(:phone_number, :nil_effective_date)

          expect(subject).to validate(
            :post,
            '/v0/profile/alternate_phone',
            200,
            headers.merge('_data' => phone.as_json)
          )
        end
      end

      it 'supports posting email address data' do
        expect(subject).to validate(:post, '/v0/profile/email', 401)

        VCR.use_cassette('evss/pciu/post_email_address') do
          email_address = build(:email_address)

          expect(subject).to validate(
            :post,
            '/v0/profile/email',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports getting full name data' do
        expect(subject).to validate(:get, '/v0/profile/full_name', 401)

        user = build(:user_with_suffix, :loa3)
        headers = { '_headers' => { 'Cookie' => sign_in(user, nil, true) } }

        expect(subject).to validate(:get, '/v0/profile/full_name', 200, headers)
      end

      it 'supports posting vet360 email address data' do
        expect(subject).to validate(:post, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('vet360/contact_information/post_email_success') do
          email_address = build(:email)

          expect(subject).to validate(
            :post,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports putting vet360 email address data' do
        expect(subject).to validate(:put, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('vet360/contact_information/put_email_success') do
          email_address = build(:email, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports deleting vet360 email address data' do
        expect(subject).to validate(:delete, '/v0/profile/email_addresses', 401)

        VCR.use_cassette('vet360/contact_information/delete_email_success') do
          email_address = build(:email, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/email_addresses',
            200,
            headers.merge('_data' => email_address.as_json)
          )
        end
      end

      it 'supports posting vet360 telephone data' do
        expect(subject).to validate(:post, '/v0/profile/telephones', 401)

        VCR.use_cassette('vet360/contact_information/post_telephone_success') do
          telephone = build(:telephone)

          expect(subject).to validate(
            :post,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports putting vet360 telephone data' do
        expect(subject).to validate(:put, '/v0/profile/telephones', 401)

        VCR.use_cassette('vet360/contact_information/put_telephone_success') do
          telephone = build(:telephone, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      it 'supports deleting vet360 telephone data' do
        expect(subject).to validate(:delete, '/v0/profile/telephones', 401)

        VCR.use_cassette('vet360/contact_information/delete_telephone_success') do
          telephone = build(:telephone, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/telephones',
            200,
            headers.merge('_data' => telephone.as_json)
          )
        end
      end

      context 'ch33 bank accounts methods' do
        let(:mhv_user) { FactoryBot.build(:ch33_dd_user) }

        it 'supports the update ch33 bank account api' do
          expect(subject).to validate(:put, '/v0/profile/ch33_bank_accounts', 401)

          VCR.use_cassette('bgs/service/update_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
            expect(subject).to validate(
              :put,
              '/v0/profile/ch33_bank_accounts',
              200,
              headers.merge(
                '_data' => {
                  account_type: 'Checking',
                  account_number: '444',
                  financial_institution_routing_number: '122239982'
                }
              )
            )
          end
        end

        it 'supports the get ch33 bank account api' do
          expect(subject).to validate(:get, '/v0/profile/ch33_bank_accounts', 401)

          VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
            expect(subject).to validate(
              :get,
              '/v0/profile/ch33_bank_accounts',
              200,
              headers
            )
          end
        end
      end

      it 'supports the address validation api' do
        expect(subject).to validate(:post, '/v0/profile/address_validation', 401)

        address = build(:vet360_address, :multiple_matches)
        VCR.use_cassette(
          'vet360/address_validation/validate_match',
          VCR::MATCH_EVERYTHING
        ) do
          VCR.use_cassette(
            'vet360/address_validation/candidate_multiple_matches',
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

      it 'supports posting vet360 address data' do
        expect(subject).to validate(:post, '/v0/profile/addresses', 401)

        VCR.use_cassette('vet360/contact_information/post_address_success') do
          address = build(:vet360_address)

          expect(subject).to validate(
            :post,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports putting vet360 address data' do
        expect(subject).to validate(:put, '/v0/profile/addresses', 401)

        VCR.use_cassette('vet360/contact_information/put_address_success') do
          address = build(:vet360_address, id: 42)

          expect(subject).to validate(
            :put,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports deleting vet360 address data' do
        expect(subject).to validate(:delete, '/v0/profile/addresses', 401)

        VCR.use_cassette('vet360/contact_information/delete_address_success') do
          address = build(:vet360_address, id: 42)

          expect(subject).to validate(
            :delete,
            '/v0/profile/addresses',
            200,
            headers.merge('_data' => address.as_json)
          )
        end
      end

      it 'supports posting vet360 permission data' do
        expect(subject).to validate(:post, '/v0/profile/permissions', 401)

        VCR.use_cassette('vet360/contact_information/post_permission_success') do
          permission = build(:permission)

          expect(subject).to validate(
            :post,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports putting vet360 permission data' do
        expect(subject).to validate(:put, '/v0/profile/permissions', 401)

        VCR.use_cassette('vet360/contact_information/put_permission_success') do
          permission = build(:permission, id: 401)

          expect(subject).to validate(
            :put,
            '/v0/profile/permissions',
            200,
            headers.merge('_data' => permission.as_json)
          )
        end
      end

      it 'supports deleting vet360 permission data' do
        expect(subject).to validate(:delete, '/v0/profile/permissions', 401)

        VCR.use_cassette('vet360/contact_information/delete_permission_success') do
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

        VCR.use_cassette('vet360/person/init_vet360_id_success') do
          expect(subject).to validate(
            :post,
            '/v0/profile/initialize_vet360_id',
            200,
            headers.merge('_data' => {})
          )
        end
      end
    end

    describe 'profile/status' do
      before do
        # vet360_id appears in the API request URI so we need it to match the cassette
        allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
          MPI::Responses::FindProfileResponse.new(
            status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
            profile: build(:mvi_profile, vet360_id: '1')
          )
        )
      end

      let(:user) { build(:user, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, nil, true) } } }

      it 'supports GETting async transaction by ID' do
        transaction = create(
          :address_transaction,
          transaction_id: 'a030185b-e88b-4e0d-a043-93e4f34c60d6',
          user_uuid: user.uuid
        )
        expect(subject).to validate(
          :get,
          '/v0/profile/status/{transaction_id}',
          401,
          'transaction_id' => transaction.transaction_id
        )

        VCR.use_cassette('vet360/contact_information/address_transaction_status') do
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

        VCR.use_cassette('vet360/contact_information/address_transaction_status') do
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
      let(:user_without_vet360_id) { build(:user_with_suffix, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user_without_vet360_id, nil, true) } } }

      before do
        allow_any_instance_of(User).to receive(:vet360_id).and_return(nil)
      end

      it 'supports GETting async person transaction by transaction ID' do
        transaction_id = '786efe0e-fd20-4da2-9019-0c00540dba4d'
        transaction = create(
          :initialize_person_transaction,
          :init_vet360_id,
          user_uuid: user_without_vet360_id.uuid,
          transaction_id: transaction_id
        )

        expect(subject).to validate(
          :get,
          '/v0/profile/person/status/{transaction_id}',
          401,
          'transaction_id' => transaction.transaction_id
        )

        VCR.use_cassette('vet360/contact_information/person_transaction_status') do
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
      let(:user) { create(:user, :loa3, uuid: '00u2fqgvbyT23TZNm2p7') }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(user, token, true) } } }

      before do
        Session.create(uuid: user.uuid, token: token)
      end

      it 'supports getting connected applications' do
        with_okta_configured do
          expect(subject).to validate(:get, '/v0/profile/connected_applications', 401)
          VCR.use_cassette('okta/grants') do
            expect(subject).to validate(:get, '/v0/profile/connected_applications', 200, headers)
          end
        end
      end

      it 'supports removing connected applications grants' do
        with_okta_configured do
          parameters = { 'application_id' => '0oa2ey2m6kEL2897N2p7' }
          expect(subject).to validate(:delete, '/v0/profile/connected_applications/{application_id}', 401, parameters)
          VCR.use_cassette('okta/delete_grants') do
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
    end

    describe 'when EVSS authorization requirements are not met' do
      let(:unauthorized_evss_user) { build(:unauthorized_evss_user, :loa3) }
      let(:headers) { { '_headers' => { 'Cookie' => sign_in(unauthorized_evss_user, nil, true) } } }

      it 'supports returning a custom 403 Forbidden response', :aggregate_failures do
        expect(subject).to validate(:get, '/v0/profile/email', 403, headers)
        expect(subject).to validate(:get, '/v0/profile/primary_phone', 403, headers)
        expect(subject).to validate(:get, '/v0/profile/alternate_phone', 403, headers)
        expect(subject).to validate(:post, '/v0/profile/email', 403, headers)
        expect(subject).to validate(:post, '/v0/profile/primary_phone', 403, headers)
        expect(subject).to validate(:post, '/v0/profile/alternate_phone', 403, headers)
      end
    end

    describe 'when MVI returns an unexpected response body' do
      it 'supports returning a custom 502 response' do
        allow_any_instance_of(MPI::Models::MviProfile).to receive(:gender).and_return(nil)
        allow_any_instance_of(MPI::Models::MviProfile).to receive(:birth_date).and_return(nil)

        VCR.use_cassette('mpi/find_candidate/missing_birthday_and_gender') do
          expect(subject).to validate(:get, '/v0/profile/personal_information', 502, headers)
        end
      end
    end

    describe 'when EMIS returns an unexpected response body' do
      it 'supports returning a custom 502 response' do
        allow(EMISRedis::MilitaryInformation).to receive_message_chain(:for_user, :service_history) { nil }

        expect(subject).to validate(:get, '/v0/profile/service_history', 502, headers)
      end
    end

    describe 'search' do
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

    describe 'notifications' do
      let(:notification_subject) { Notification::FORM_10_10EZ }

      describe 'POST /v0/notifications' do
        let(:post_body) do
          {
            subject: notification_subject,
            read: false
          }
        end

        it 'supports posting notification data' do
          expect(subject).to validate(
            :post,
            '/v0/notifications',
            200,
            headers.merge('_data' => post_body)
          )
        end

        it 'supports authorization validation' do
          expect(subject).to validate(
            :post,
            '/v0/notifications',
            401,
            '_data' => post_body
          )
        end

        it 'supports validating posted notification data' do
          expect(subject).to validate(
            :post,
            '/v0/notifications',
            422,
            headers.merge('_data' => post_body.merge(subject: 'random_subject'))
          )
        end
      end

      describe 'GET /v0/notifications/{subject}' do
        context 'when user has an associated Notification record' do
          let!(:notification) do
            create :notification, account_id: mhv_user.account.id, subject: notification_subject
          end

          it 'supports getting dismissed status data' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/{subject}',
              200,
              headers.merge('subject' => notification_subject)
            )
          end
        end

        context 'when user does not have an associated Notification record' do
          it 'supports record not found feedback' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/{subject}',
              404,
              headers.merge('subject' => notification_subject)
            )
          end
        end

        context 'authorization' do
          it 'supports authorization validation' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/{subject}',
              401,
              'subject' => notification_subject
            )
          end
        end

        context 'when the passed subject is not defined in the Notification#subject enum' do
          it 'supports invalid subject validation' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/{subject}',
              422,
              headers.merge('subject' => 'random_subject')
            )
          end
        end
      end

      describe 'PATCH /v0/notifications/{subject}' do
        let(:patch_body) { { read: true } }

        context 'user has an existing Notification record with the passed subject' do
          let!(:notification) do
            create :notification, :dismissed_status, account_id: mhv_user.account.id, read_at: Time.current
          end

          it 'supports updating notification data' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/{subject}',
              200,
              headers.merge('_data' => patch_body, 'subject' => notification_subject)
            )
          end

          it 'supports authorization validation' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/{subject}',
              401,
              '_data' => patch_body, 'subject' => notification_subject
            )
          end

          it 'supports validating updated notification data' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/{subject}',
              422,
              headers.merge('_data' => patch_body, 'subject' => 'random_subject')
            )
          end
        end

        context 'user does not have a Notification record with the passed subject' do
          it 'supports validating the presence of an existing record to be updated' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/{subject}',
              404,
              headers.merge('_data' => patch_body, 'subject' => notification_subject)
            )
          end
        end
      end

      describe 'GET /v0/notifications/dismissed_statuses/{subject}' do
        context 'when user has an associated Notification record' do
          let!(:notification) do
            create :notification, :dismissed_status, account_id: mhv_user.account.id, read_at: Time.current
          end

          it 'supports getting dismissed status data' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/dismissed_statuses/{subject}',
              200,
              headers.merge('subject' => notification_subject)
            )
          end
        end

        context 'when user does not have an associated Notification record' do
          it 'supports record not found feedback' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/dismissed_statuses/{subject}',
              404,
              headers.merge('subject' => notification_subject)
            )
          end
        end

        context 'authorization' do
          it 'supports authorization validation' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/dismissed_statuses/{subject}',
              401,
              'subject' => notification_subject
            )
          end
        end

        context 'when the passed subject is not defined in the Notification#subject enum' do
          it 'supports invalid subject validation' do
            expect(subject).to validate(
              :get,
              '/v0/notifications/dismissed_statuses/{subject}',
              422,
              headers.merge('subject' => 'random_subject')
            )
          end
        end
      end

      describe 'POST /v0/notifications/dismissed_statuses' do
        let(:post_body) do
          {
            subject: notification_subject,
            status: Notification::PENDING_MT,
            status_effective_at: '2019-04-23T00:00:00.000-06:00'
          }
        end

        it 'supports posting dismissed status data' do
          expect(subject).to validate(
            :post,
            '/v0/notifications/dismissed_statuses',
            200,
            headers.merge('_data' => post_body)
          )
        end

        it 'supports authorization validation' do
          expect(subject).to validate(
            :post,
            '/v0/notifications/dismissed_statuses',
            401,
            '_data' => post_body
          )
        end

        it 'supports validating posted dismissed status data' do
          expect(subject).to validate(
            :post,
            '/v0/notifications/dismissed_statuses',
            422,
            headers.merge('_data' => post_body.merge(status: 'random_status'))
          )
        end
      end

      describe 'PATCH /v0/notifications/dismissed_statuses/{subject}' do
        let(:patch_body) do
          {
            status: Notification::CLOSED,
            status_effective_at: '2019-04-23T00:00:00.000-06:00'
          }
        end

        context 'user has an existing Notification record with the passed subject' do
          let!(:notification) do
            create :notification, :dismissed_status, account_id: mhv_user.account.id, read_at: Time.current
          end

          it 'supports updating dismissed status data' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/dismissed_statuses/{subject}',
              200,
              headers.merge('_data' => patch_body, 'subject' => notification_subject)
            )
          end

          it 'supports authorization validation' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/dismissed_statuses/{subject}',
              401,
              '_data' => patch_body, 'subject' => notification_subject
            )
          end

          it 'supports validating updated dismissed status data' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/dismissed_statuses/{subject}',
              422,
              headers.merge('_data' => patch_body.merge(status: 'random_status'), 'subject' => notification_subject)
            )
          end
        end

        context 'user does not have a Notification record with the passed subject' do
          it 'supports validating the presence of an existing record to be updated' do
            expect(subject).to validate(
              :patch,
              '/v0/notifications/dismissed_statuses/{subject}',
              404,
              headers.merge('_data' => patch_body, 'subject' => notification_subject)
            )
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
    end

    describe 'asks' do
      describe 'POST v0/ask/asks' do
        let(:post_body) do
          {
            inquiry: {
              form: JSON.generate(
                {
                  fullName: {
                    first: 'Obi Wan',
                    last: 'Kenobi'
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
                  preferredContactMethod: 'email',
                  email: 'obi1kenobi@gmail.com',
                  address: {
                    country: 'USA'
                  }
                }
              )
            }
          }
        end

        it 'supports posting contact us form data' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

          expect(subject).to validate(
            :post,
            '/v0/ask/asks',
            201,
            headers.merge('_data' => post_body)
          )
        end

        it 'supports validating posted contact us form data' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

          expect(subject).to validate(
            :post,
            '/v0/ask/asks',
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
            '/v0/ask/asks',
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
    end

    describe 'dependents applications' do
      it 'supports getting dependent information' do
        expect(subject).to validate(:get, '/v0/dependents_applications/show', 401)
        VCR.use_cassette('bgs/claimant_web_service/dependents') do
          expect(subject).to validate(:get, '/v0/dependents_applications/show', 200, headers)
        end
      end

      it 'supports adding a dependency claim' do
        expect(subject).to validate(
          :post,
          '/v0/dependents_applications',
          200,
          headers.merge(
            '_data' => build(:dependency_claim).parsed_form
          )
        )

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
        FactoryBot.create(:evss_claim, id: 1, evss_id: 189_625,
                                       user_uuid: mhv_user.uuid, data: {})
      end

      it 'uploads a document to support a claim' do
        expect(subject).to validate(
          :post,
          '/v0/evss_claims/{evss_claim_id}/documents',
          202,
          headers.merge('_data' => { file: fixture_file_upload('/files/doctors-note.pdf', 'application/pdf'),
                                     tracked_item_id: 33,
                                     document_type: 'L023' }, 'evss_claim_id' => 189_625)
        )
      end
      it 'rejects a malformed document' do
        expect(subject).to validate(
          :post,
          '/v0/evss_claims/{evss_claim_id}/documents',
          422,
          headers.merge('_data' => { file: fixture_file_upload('spec/fixtures/files/malformed-pdf.pdf',
                                                               'application/pdf'),
                                     tracked_item_id: 33,
                                     document_type: 'L023' }, 'evss_claim_id' => 189_625)
        )
      end
    end
  end

  context 'and' do
    it 'tests all documented routes' do
      subject.untested_mappings.delete('/v0/letters/{id}') # exclude this route as it returns a binary
      expect(subject).to validate_all_paths
    end
  end
end
