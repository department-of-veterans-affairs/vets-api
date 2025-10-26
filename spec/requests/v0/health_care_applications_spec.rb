# frozen_string_literal: true

require 'rails_helper'
require 'hca/service'
require 'bgs/service'

RSpec.describe 'V0::HealthCareApplications', type: %i[request serializer] do
  let(:test_veteran) do
    JSON.parse(
      Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json').read
    )
  end

  let(:headers) do
    {
      'ACCEPT' => 'application/json',
      'CONTENT_TYPE' => 'application/json',
      'HTTP_X_KEY_INFLECTION' => 'camel'
    }
  end

  describe 'GET rating_info' do
    let(:current_user) { build(:ch33_dd_user) }

    before do
      allow(Flipper).to receive(:enabled?).with(:hca_disable_bgs_service).and_return(false)
      sign_in_as(current_user)
    end

    it 'returns the users rating info' do
      VCR.use_cassette('bgs/service/find_rating_data', VCR::MATCH_EVERYTHING) do
        get(rating_info_v0_health_care_applications_path)
      end

      expect(JSON.parse(response.body)['data']['attributes']).to eq(
        { 'user_percent_of_disability' => 100 }
      )
    end

    context 'hca_disable_bgs_service enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:hca_disable_bgs_service).and_return(true)
      end

      it 'does not call the BGS Service and returns the rating info as 0' do
        expect_any_instance_of(BGS::Service).not_to receive(:find_rating_data)

        get(rating_info_v0_health_care_applications_path)

        expect(JSON.parse(response.body)['data']['attributes']).to eq(
          { 'user_percent_of_disability' => 0 }
        )
      end
    end

    context 'User not found' do
      before do
        error404 = Common::Exceptions::RecordNotFound.new(1)
        allow_any_instance_of(BGS::Service).to receive(:find_rating_data).and_raise(error404)
      end

      it 'returns a 404 if user not found' do
        get(rating_info_v0_health_care_applications_path)

        errors = JSON.parse(response.body)['errors']
        expect(errors.first['title']).to eq('Record not found')
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with an loa1 user' do
      let(:current_user) { build(:user, :loa1) }

      it 'errors if user is not loa3' do
        get(rating_info_v0_health_care_applications_path)

        errors = JSON.parse(response.body)['errors']
        expect(errors.first['title']).to eq('Forbidden')
      end
    end
  end

  describe 'GET healthcheck' do
    subject do
      get(healthcheck_v0_health_care_applications_path)
    end

    let(:body) do
      { 'formSubmissionId' => 377_609_264,
        'timestamp' => '2024-08-20T11:38:44.535-05:00' }
    end
    let(:es_stub) { double(health_check: { up: true }) }

    it 'calls ES' do
      VCR.use_cassette('hca/health_check', match_requests_on: [:body]) do
        subject
        expect(JSON.parse(response.body)).to eq(body)
      end
    end
  end

  describe 'enrollment_status' do
    let(:success_response) do
      { application_date: '2018-01-24T00:00:00.000-06:00',
        enrollment_date: nil,
        preferred_facility: '987 - CHEY6',
        parsed_status: HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE,
        primary_eligibility: 'SC LESS THAN 50%',
        can_submit_financial_info: true }
    end

    let(:loa1_response) do
      { parsed_status: HCA::EnrollmentEligibility::Constants::LOGIN_REQUIRED }
    end

    context 'GET enrollment_status' do
      context 'with user attributes' do
        let(:user_attributes) do
          {
            userAttributes: build(:health_care_application).parsed_form.slice(
              'veteranFullName', 'veteranDateOfBirth',
              'veteranSocialSecurityNumber', 'gender'
            )
          }
        end

        it 'returns 404 unless signed in' do
          allow(HealthCareApplication).to receive(:user_icn).and_return('123')
          allow(HealthCareApplication).to receive(:enrollment_status).with(
            '123', nil
          ).and_return(loa1_response)

          get(enrollment_status_v0_health_care_applications_path, params: user_attributes)
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'with a signed in user' do
        let(:current_user) { build(:user, :loa3) }

        before do
          sign_in_as(current_user)
        end

        context 'with a user with no icn' do
          before do
            allow_any_instance_of(User).to receive(:icn).and_return(nil)
          end

          it 'returns 404' do
            get(enrollment_status_v0_health_care_applications_path)
            expect(response).to have_http_status(:not_found)
          end
        end

        context 'without user passed attributes' do
          let(:enrolled) { HCA::EnrollmentEligibility::Constants::ENROLLED }
          let(:success_response) do
            {
              application_date: '2018-12-27T00:00:00.000-06:00',
              enrollment_date: '2018-12-27T17:15:39.000-06:00',
              preferred_facility: '988 - DAYT20',
              effective_date: '2019-01-02T21:58:55.000-06:00',
              primary_eligibility: 'SC LESS THAN 50%',
              priority_group: 'Group 3',
              can_submit_financial_info: true,
              parsed_status: enrolled
            }
          end

          before do
            allow_any_instance_of(User).to receive(:icn).and_return('1013032368V065534')
          end

          it 'returns the enrollment status data' do
            VCR.use_cassette('hca/ee/lookup_user', erb: true) do
              get(enrollment_status_v0_health_care_applications_path)

              expect(response.body).to eq(success_response.to_json)
            end
          end
        end
      end
    end

    context 'POST enrollment_status' do
      let(:headers) do
        {
          'ACCEPT' => 'application/json',
          'CONTENT_TYPE' => 'application/json'
        }
      end

      context 'with user attributes' do
        let(:params) do
          {
            user_attributes: build(:health_care_application).parsed_form.deep_transform_keys(&:underscore).slice(
              'veteran_full_name', 'veteran_date_of_birth',
              'veteran_social_security_number', 'gender'
            )
          }.to_json
        end

        it 'logs user loa' do
          allow(Sentry).to receive(:set_extras)
          expect(Sentry).to receive(:set_extras).with(user_loa: nil)
          post(enrollment_status_v0_health_care_applications_path, params:, headers:)
        end

        it 'returns the enrollment status data' do
          expect(HealthCareApplication).to receive(:user_icn).and_return('123')
          expect(HealthCareApplication).to receive(:enrollment_status).with(
            '123', nil
          ).and_return(loa1_response)

          post(enrollment_status_v0_health_care_applications_path, params:, headers:)

          expect(response.body).to eq(loa1_response.to_json)
        end

        context 'when the request is rate limited' do
          it 'returns 429' do
            expect(HCA::RateLimitedSearch).to receive(
              :create_rate_limited_searches
            ).and_raise(RateLimitedSearch::RateLimitedError)

            post(enrollment_status_v0_health_care_applications_path, params:, headers:)
            expect(response).to have_http_status(:too_many_requests)
          end
        end
      end

      context 'with a signed in user' do
        let(:current_user) { build(:user, :loa3) }
        let(:params) { { userAttributes: build(:health_care_application).parsed_form }.to_json }

        before do
          sign_in_as(current_user)
        end

        context 'with a user with no icn' do
          before do
            allow_any_instance_of(User).to receive(:icn).and_return(nil)
          end

          it 'returns 404' do
            post(
              enrollment_status_v0_health_care_applications_path,
              params:,
              headers:
            )
            expect(response).to have_http_status(:not_found)
          end
        end

        context 'with user passed attributes' do
          it 'returns the enrollment status data' do
            expect(HealthCareApplication).to receive(:enrollment_status).with(
              current_user.icn, true
            ).and_return(success_response)

            post(
              enrollment_status_v0_health_care_applications_path,
              params:,
              headers:
            )

            expect(response.body).to eq(success_response.to_json)
          end
        end

        context 'without user passed attributes' do
          let(:enrolled) { HCA::EnrollmentEligibility::Constants::ENROLLED }
          let(:success_response) do
            {
              application_date: '2018-12-27T00:00:00.000-06:00',
              enrollment_date: '2018-12-27T17:15:39.000-06:00',
              preferred_facility: '988 - DAYT20',
              effective_date: '2019-01-02T21:58:55.000-06:00',
              primary_eligibility: 'SC LESS THAN 50%',
              priority_group: 'Group 3',
              can_submit_financial_info: true,
              parsed_status: enrolled
            }
          end

          it 'returns the enrollment status data' do
            allow_any_instance_of(User).to receive(:icn).and_return('1013032368V065534')

            VCR.use_cassette('hca/ee/lookup_user', erb: true) do
              post(enrollment_status_v0_health_care_applications_path)

              expect(response.body).to eq(success_response.to_json)
            end
          end
        end
      end
    end
  end

  describe 'GET show' do
    let(:health_care_application) { create(:health_care_application) }

    it 'shows a health care application' do
      get(v0_health_care_application_path(id: health_care_application.id))
      expect(JSON.parse(response.body)).to eq(
        'data' => {
          'id' => health_care_application.id.to_s,
          'type' => 'health_care_applications',
          'attributes' => {
            'state' => 'pending',
            'form_submission_id' => nil,
            'timestamp' => nil
          }
        }
      )
    end
  end

  describe 'GET facilities' do
    it 'triggers HCA::StdInstitutionImportJob when the HealthFacility table is empty' do
      HealthFacility.delete_all

      import_job = instance_double(HCA::StdInstitutionImportJob)
      expect(HCA::StdInstitutionImportJob).to receive(:new).and_return(import_job)
      expect(import_job).to receive(:import_facilities).with(run_sync: true)

      get(facilities_v0_health_care_applications_path(state: 'OH'))
    end

    it 'does not trigger HCA::StdInstitutionImportJob when HealthFacility table is populated' do
      create(:health_facility, name: 'Test Facility', station_number: '123', postal_name: 'OH')
      expect(HCA::StdInstitutionImportJob).not_to receive(:new)

      get(facilities_v0_health_care_applications_path(state: 'OH'))
    end

    it 'responds with serialized facilities data for supported facilities' do
      mock_facilities = [
        { name: 'My VA Facility', station_number: '123', postal_name: 'OH' },
        { name: 'A VA Facility', station_number: '222', postal_name: 'OH' },
        { name: 'My Other VA Facility', station_number: '231', postal_name: 'NH' }
      ]
      mock_facilities.each { |attrs| create(:health_facility, attrs) }

      get(facilities_v0_health_care_applications_path(state: 'OH'))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly({
                                                        'id' => mock_facilities[0][:station_number],
                                                        'name' => mock_facilities[0][:name]
                                                      }, {
                                                        'id' => mock_facilities[1][:station_number],
                                                        'name' => mock_facilities[1][:name]
                                                      })
    end
  end

  describe 'POST create' do
    subject do
      post(
        v0_health_care_applications_path,
        params: params.to_json,
        headers:
      )
    end

    context 'with invalid params' do
      before do
        allow(Settings.sentry).to receive(:dsn).and_return('asdf')
      end

      let(:params) do
        {
          form: test_veteran.except('privacyAgreementAccepted').to_json
        }
      end

      it 'shows the validation errors' do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'form - object at root is missing required properties: privacyAgreementAccepted'
          )
        ).to be(true)
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          form: test_veteran.to_json
        }
      end

      def self.expect_async_submit
        it 'submits async' do
          subject
          body = JSON.parse(response.body)
          expect(body).to eq(
            'data' => {
              'id' => HealthCareApplication.last.id.to_s,
              'type' => 'health_care_applications',
              'attributes' => {
                'state' => 'pending',
                'formSubmissionId' => nil,
                'timestamp' => nil
              }
            }
          )
        end
      end

      context 'anonymously' do
        let(:body) do
          {
            'formSubmissionId' => 436_426_165,
            'timestamp' => '2024-08-20T12:08:06.729-05:00',
            'success' => true
          }
        end

        context 'with an email set' do
          before do
            expect(HealthCareApplication).to receive(:user_icn).and_return('123')
          end

          expect_async_submit
        end

        context 'with no email set' do
          before do
            test_veteran.delete('email')
          end

          it 'increments statsd' do
            expect { subject }.to trigger_statsd_increment('api.1010ez.submission_attempt')
          end

          context 'with a short form submission' do
            before do
              test_veteran.delete('lastServiceBranch')
            end

            it 'increments statsd' do
              expect { subject }.to trigger_statsd_increment('api.1010ez.submission_attempt_short_form')
            end
          end

          it 'renders success', run_at: '2017-01-31' do
            expect(HealthCareApplication).to receive(:user_icn).twice.and_return('123')
            VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
              subject
              expect(JSON.parse(response.body)).to eq(body)
            end
          end
        end
      end

      context 'while authenticated', :skip_mvi do
        let!(:in_progress_form) { create(:in_progress_form, user_uuid: current_user.uuid, form_id: '1010ez') }
        let(:current_user) { build(:user, :mhv) }
        let(:body) do
          {
            'formSubmissionId' => 436_426_340,
            'timestamp' => '2024-08-20T12:26:48.275-05:00',
            'success' => true
          }
        end

        before do
          sign_in_as(current_user)
          test_veteran.delete('email')
        end

        it 'renders success and enqueues job to delete InProgressForm', run_at: '2017-01-31' do
          VCR.use_cassette('hca/submit_auth', match_requests_on: [:body]) do
            expect_any_instance_of(HealthCareApplication).to receive(:prefill_fields)

            expect(DeleteInProgressFormJob).to receive(:perform_in).with(
              5.minutes,
              '1010ez',
              current_user.uuid
            )

            subject
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end

      context 'with an invalid discharge date' do
        let(:discharge_date) { Time.zone.today + 181.days }
        let(:params) do
          test_veteran['lastDischargeDate'] = discharge_date.strftime('%Y-%m-%d')
          test_veteran.delete('email')

          {
            form: test_veteran.to_json
          }
        end

        let(:body) do
          {
            'errors' => [
              {
                'title' => 'Invalid field value',
                'detail' => "\"#{discharge_date.strftime('%Y-%m-%d')}\" is not a valid value for \"lastDischargeDate\"",
                'code' => '103',
                'status' => '400'
              }
            ]
          }
        end

        it 'raises an invalid field value error' do
          expect(HealthCareApplication).to receive(:user_icn).twice.and_return('123')
          VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
            subject
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end

      context 'when hca service raises an error' do
        before do
          test_veteran.delete('email')
          allow_any_instance_of(HCA::Service).to receive(:submit_form) do
            raise error
          end
        end

        context 'with a validation error' do
          let(:error) { HCA::SOAPParser::ValidationError.new }

          it 'renders error message' do
            expect(HealthCareApplication).to receive(:user_icn).twice.and_return('123')

            subject

            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)).to eq(
              'errors' => [
                {
                  'title' => 'Operation failed',
                  'detail' => 'Validation error',
                  'code' => 'HCA422',
                  'status' => '422'
                }
              ]
            )
          end
        end

        context 'with a SOAP error' do
          let(:error) { Common::Client::Errors::HTTPError.new('error message') }

          before do
            allow(Settings.sentry).to receive(:dsn).and_return('asdf')
          end

          it 'renders error message' do
            expect(HealthCareApplication).to receive(:user_icn).twice.and_return('123')

            subject

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)).to eq(
              'errors' => [
                {
                  'title' => 'Operation failed',
                  'detail' => 'error message',
                  'code' => 'VA900',
                  'status' => '400'
                }
              ]
            )
          end
        end
      end

      context 'with an arbitrary medical facility ID' do
        let(:current_user) { create(:user) }
        let(:params) do
          test_veteran['vaMedicalFacility'] = '000'
          {
            form: test_veteran.to_json
          }
        end
        let(:body) do
          {
            'formSubmissionId' => nil,
            'timestamp' => nil,
            'state' => 'pending'
          }
        end

        before do
          sign_in_as(current_user)
        end

        it 'does not error on vaMedicalFacility validation' do
          subject

          expect(JSON.parse(response.body)['errors']).to be_blank
          expect(JSON.parse(response.body)['data']['attributes']).to eq(body)
        end
      end
    end
  end

  describe 'POST /v0/health_care_applications/download_pdf' do
    subject do
      post('/v0/health_care_applications/download_pdf', params: body, headers:)
    end

    let(:endpoint) { '/v0/health_care_applications/download_pdf' }
    let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10EZ_from_response.pdf' }
    let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10EZ', 'unsigned', 'simple.pdf' }

    let!(:form_data) { get_fixture('pdf_fill/10-10EZ/simple').to_json }
    let!(:health_care_application) { build(:health_care_application, form: form_data) }
    let(:body) { { form: form_data, asyncCompatible: true }.to_json }

    before do
      allow(SecureRandom).to receive(:uuid).and_return('saved-claim-guid', 'file-name-uuid')
      allow(HealthCareApplication).to receive(:new)
        .with(hash_including('form' => form_data))
        .and_return(health_care_application)
    end

    after do
      FileUtils.rm_f(response_pdf)
    end

    it 'returns a completed PDF' do
      subject

      expect(response).to have_http_status(:ok)

      veteran_full_name = health_care_application.parsed_form['veteranFullName']
      expected_filename = "10-10EZ_#{veteran_full_name['first']}_#{veteran_full_name['last']}.pdf"

      expect(response.headers['Content-Disposition']).to include("filename=\"#{expected_filename}\"")
      expect(response.content_type).to eq('application/pdf')
      expect(response.body).to start_with('%PDF')
    end

    it 'ensures the tmp file is deleted when send_data fails' do
      allow_any_instance_of(ApplicationController).to receive(:send_data).and_raise(StandardError, 'send_data failed')

      subject

      expect(response).to have_http_status(:internal_server_error)
      expect(
        File.exist?('tmp/pdfs/10-10EZ_file-name-uuid.pdf')
      ).to be(false)
    end

    it 'ensures the tmp file is deleted when fill_form fails after retries' do
      expect(PdfFill::Filler).to receive(:fill_form).exactly(3).times.and_raise(StandardError, 'error filling form')

      subject

      expect(response).to have_http_status(:internal_server_error)

      expect(
        File.exist?('tmp/pdfs/10-10EZ_file-name-uuid.pdf')
      ).to be(false)
    end
  end
end
