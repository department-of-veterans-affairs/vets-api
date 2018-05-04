# frozen_string_literal: true

require 'rails_helper'
require 'hca/service'

RSpec.describe 'Health Care Application Integration', type: %i[request serializer] do
  let(:test_veteran) do
    JSON.parse(
      File.read(
        Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json')
      )
    )
  end

  describe 'GET healthcheck' do
    subject do
      get(healthcheck_v0_health_care_applications_path)
    end
    let(:body) do
      { 'formSubmissionId' => 377_609_264,
        'timestamp' => '2016-12-12T08:06:08.423-06:00' }
    end
    let(:es_stub) { double(health_check: { up: true }) }

    it 'should call ES' do
      VCR.use_cassette('hca/health_check', match_requests_on: [:body]) do
        subject
        expect(JSON.parse(response.body)).to eq(body)
      end
    end
  end

  describe 'GET show' do
    it 'should render json of the application' do
      health_care_application = create(:health_care_application)

      get(
        v0_health_care_application_path(id: health_care_application.id)
      )
      expect(response.body).to eq(serialize(health_care_application))
    end
  end

  describe 'POST create' do
    subject do
      post(
        v0_health_care_applications_path,
        params.to_json,
        'CONTENT_TYPE' => 'application/json',
        'HTTP_X_KEY_INFLECTION' => 'camel'
      )
    end

    context 'with invalid params' do
      before do
        Settings.sentry.dsn = 'asdf'
      end
      after do
        Settings.sentry.dsn = nil
      end
      let(:params) do
        {
          form: test_veteran.except('privacyAgreementAccepted').to_json
        }
      end

      it 'should show the validation errors' do
        subject

        expect(response.code).to eq('422')
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

      def test_submission
        HCA::SubmissionJob.drain

        health_care_application = HealthCareApplication.find(JSON.parse(response.body)['data']['id'])
        expect(health_care_application.state).to eq('success')
        expect(health_care_application.form_submission_id).to eq(body['formSubmissionId'])
        expect(health_care_application.timestamp).to eq(body['timestamp'])
      end

      context 'anonymously' do
        let(:body) do
          { 'formSubmissionId' => 40_124_668_140,
            'timestamp' => '2016-05-25T04:59:39.345-05:00',
            'success' => true }
        end

        it 'should render success', run_at: '2017-01-31' do
          VCR.use_cassette('hca/submit_anon', match_requests_on: [:body]) do
            subject
            test_submission
          end
        end
      end

      context 'while authenticated', skip_mvi: true do
        let(:current_user) { create(:user, :mhv) }

        before do
          use_authenticated_current_user(current_user: current_user)
        end

        let(:body) do
          { 'formSubmissionId' => 40_125_311_094,
            'timestamp' => '2017-02-08T13:50:32.020-06:00',
            'success' => true }
        end

        it 'should render success and delete the saved form', run_at: '2017-01-31' do
          VCR.use_cassette('hca/submit_auth', match_requests_on: [:body]) do
            expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('10-10EZ').once
            subject

            test_submission
          end
        end
      end
    end
  end
end
