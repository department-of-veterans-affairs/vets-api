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

RSpec.describe 'the v0 API documentation (Part 2)', order: :defined, type: %i[apivore request] do
  include AuthenticatedSessionHelper

  subject { Apivore::SwaggerChecker.instance_for('/v0/apidocs.json') }

  let(:mhv_user) { build(:user, :mhv, middle_name: 'Bob') }

  context 'has valid paths' do
    let(:headers) { { '_headers' => { 'Cookie' => sign_in(mhv_user, nil, true) } } }

    before do
      create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid)
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

        it 'validates the route' do
          allow_any_instance_of(DebtsApi::V0::DigitalDisputeSubmissionService).to receive(:call).and_return(
            { success: true, message: 'Digital dispute submission received successfully' }
          )
          expect(subject).to validate(
            :post,
            '/debts_api/v0/digital_disputes',
            200,
            headers.merge(
              '_data' => { files: [pdf_file] }
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
  end
end