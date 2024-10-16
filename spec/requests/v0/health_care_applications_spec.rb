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

  describe 'GET rating_info' do
    let(:current_user) { build(:ch33_dd_user) }

    before do
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

  describe 'GET enrollment_status' do
    let(:inelig_character_of_discharge) { HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE }
    let(:login_required) { HCA::EnrollmentEligibility::Constants::LOGIN_REQUIRED }
    let(:success_response) do
      { application_date: '2018-01-24T00:00:00.000-06:00',
        enrollment_date: nil,
        preferred_facility: '987 - CHEY6',
        parsed_status: inelig_character_of_discharge,
        primary_eligibility: 'SC LESS THAN 50%',
        can_submit_financial_info: true }
    end
    let(:loa1_response) do
      { parsed_status: login_required }
    end

    context 'with user attributes' do
      let(:user_attributes) do
        {
          userAttributes: build(:health_care_application).parsed_form.slice(
            'veteranFullName', 'veteranDateOfBirth',
            'veteranSocialSecurityNumber', 'gender'
          )
        }
      end

      it 'logs user loa' do
        allow(Sentry).to receive(:set_extras)
        expect(Sentry).to receive(:set_extras).with(user_loa: nil)

        get(enrollment_status_v0_health_care_applications_path, params: user_attributes)
      end

      it 'returns the enrollment status data' do
        expect(HealthCareApplication).to receive(:user_icn).and_return('123')
        expect(HealthCareApplication).to receive(:enrollment_status).with(
          '123', nil
        ).and_return(loa1_response)

        get(enrollment_status_v0_health_care_applications_path, params: user_attributes)

        expect(response.body).to eq(loa1_response.to_json)
      end

      context 'when the request is rate limited' do
        it 'returns 429' do
          expect(HCA::RateLimitedSearch).to receive(
            :create_rate_limited_searches
          ).and_raise(RateLimitedSearch::RateLimitedError)

          get(enrollment_status_v0_health_care_applications_path, params: user_attributes)
          expect(response).to have_http_status(:too_many_requests)
        end
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
          get(enrollment_status_v0_health_care_applications_path,
              params: { userAttributes: build(:health_care_application).parsed_form })
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'with user passed attributes' do
        it 'returns the enrollment status data' do
          expect(HealthCareApplication).to receive(:enrollment_status).with(
            current_user.icn, true
          ).and_return(success_response)

          get(enrollment_status_v0_health_care_applications_path,
              params: { userAttributes: build(:health_care_application).parsed_form })

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
            get(enrollment_status_v0_health_care_applications_path)

            expect(response.body).to eq(success_response.to_json)
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
    it 'responds with facilities data' do
      StdInstitutionFacility.create(station_number: '042')

      VCR.use_cassette('lighthouse/facilities/v1/200_facilities_facility_ids', match_requests_on: %i[method uri]) do
        get(facilities_v0_health_care_applications_path(facilityIds: %w[vha_757 vha_358]))
      end
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body[0]).to eq({ 'access' => nil,
                                              'active_status' => nil,
                                              'address' => {
                                                'mailing' => { 'zip' => '66713', 'city' => 'Leavenworth',
                                                               'state' => 'KS', 'address1' => '150 Muncie Rd' },
                                                'physical' => { 'zip' => '66713', 'city' => 'Baxter Springs',
                                                                'state' => 'KS',
                                                                'address1' => 'Baxter Springs City Cemetery' }
                                              },
                                              'classification' => 'Soldiers Lot',
                                              'detailed_services' => nil,
                                              'distance' => nil,
                                              'facility_type' => 'va_cemetery',
                                              'facility_type_prefix' => 'nca',
                                              'feedback' => nil,
                                              'hours' =>
                                               { 'monday' => 'Sunrise - Sundown',
                                                 'tuesday' => 'Sunrise - Sundown',
                                                 'wednesday' => 'Sunrise - Sundown',
                                                 'thursday' => 'Sunrise - Sundown',
                                                 'friday' => 'Sunrise - Sundown',
                                                 'saturday' => 'Sunrise - Sundown',
                                                 'sunday' => 'Sunrise - Sundown' },
                                              'id' => 'nca_042',
                                              'lat' => 37.0320575,
                                              'long' => -94.7706605,
                                              'mobile' => nil,
                                              'name' => "Baxter Springs City Soldiers' Lot",
                                              'operating_status' => { 'code' => 'NORMAL' },
                                              'operational_hours_special_instructions' => nil,
                                              'parent' => nil,
                                              'phone' => { 'fax' => '9137584136', 'main' => '9137584105' },
                                              'services' => nil,
                                              'type' => 'va_facilities',
                                              'unique_id' => '042',
                                              'visn' => nil,
                                              'website' => 'https://www.cem.va.gov/cems/lots/BaxterSprings.asp' })
    end

    it 'filters out facilities not yet supported downstream' do
      VCR.use_cassette('lighthouse/facilities/v1/200_facilities_facility_ids', match_requests_on: %i[method uri]) do
        get(facilities_v0_health_care_applications_path(facilityIds: %w[vha_757 vha_358]))
      end
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body[0]).to be_nil
    end
  end

  describe 'POST create' do
    subject do
      post(v0_health_care_applications_path,
           params: params.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_KEY_INFLECTION' => 'camel' })
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
            "The property '#/' did not contain a required property of 'privacyAgreementAccepted'"
          )
        ).to eq(true)
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
            'data' =>
           { 'id' => HealthCareApplication.last.id.to_s,
             'type' => 'health_care_applications',
             'attributes' =>
             { 'state' => 'pending', 'formSubmissionId' => nil, 'timestamp' => nil } }
          )
        end
      end

      context 'anonymously' do
        let(:body) do
          { 'formSubmissionId' => 436_426_165,
            'timestamp' => '2024-08-20T12:08:06.729-05:00',
            'success' => true }
        end

        context 'with an email set' do
          expect_async_submit
        end

        context 'with no email set' do
          before do
            test_veteran.delete('email')
          end

          context 'with async_all set' do
            before do
              params[:async_all] = true
            end

            expect_async_submit
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
            VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
              subject
              expect(JSON.parse(response.body)).to eq(body)
            end
          end
        end
      end

      context 'while authenticated', :skip_mvi do
        let(:current_user) { build(:user, :mhv) }
        let(:body) do
          { 'formSubmissionId' => 436_426_340,
            'timestamp' => '2024-08-20T12:26:48.275-05:00',
            'success' => true }
        end

        before do
          sign_in_as(current_user)
          test_veteran.delete('email')
        end

        it 'renders success and delete the saved form', run_at: '2017-01-31' do
          VCR.use_cassette('hca/submit_auth', match_requests_on: [:body]) do
            expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('1010ez').once
            expect_any_instance_of(HealthCareApplication).to receive(:prefill_fields)
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
          VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
            subject
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end

      context 'when hca service raises an error' do
        before do
          test_veteran.delete('email')
          allow_any_instance_of(HCA::Service).to receive(:post) do
            raise error
          end
        end

        context 'with a validation error' do
          let(:error) { HCA::SOAPParser::ValidationError.new }

          it 'renders error message' do
            subject

            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)).to eq(
              'errors' => [
                { 'title' => 'Operation failed', 'detail' => 'Validation error', 'code' => 'HCA422', 'status' => '422' }
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
            expect(Sentry).to receive(:capture_exception).with(error, level: 'error').once

            subject

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.body)).to eq(
              'errors' => [
                { 'title' => 'Operation failed', 'detail' => 'error message', 'code' => 'VA900', 'status' => '400' }
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
end
