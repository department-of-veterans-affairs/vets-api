# frozen_string_literal: true
require 'rails_helper'
require 'hca/service'

RSpec.describe 'Health Care Application Integration', type: [:request, :serializer] do
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

      it 'should log the validation errors' do
        expect(Raven).to receive(:tags_context).once.with(validation: 'health_care_application')
        expect(Raven).to receive(:capture_message).with(/privacyAgreementAccepted/, level: :error)

        subject
      end
    end

    context 'with valid params' do
      let(:params) do
        {
          form: test_veteran.to_json
        }
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
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end

      context 'while authenticated', skip_mvi: true do
        let(:current_user) { build(:user, :mhv) }

        before do
          profile = build(:mvi_profile, icn: '1000123456V123456')
          stub_mvi(profile)
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
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end

      context 'with a SOAP error' do
        let(:error) { Common::Client::Errors::HTTPError.new('error message') }

        before do
          allow_any_instance_of(HCA::Service).to receive(:post) do
            raise error
          end
          Settings.sentry.dsn = 'asdf'
        end
        after do
          Settings.sentry.dsn = nil
        end

        it 'should render error message' do
          expect(Raven).to receive(:capture_exception).with(error).twice

          subject

          expect(response.code).to eq('400')
          expect(JSON.parse(response.body)).to eq(
            'errors' => [
              { 'title' => 'Operation failed', 'detail' => 'error message', 'code' => 'VA900', 'status' => '400' }
            ]
          )
        end
      end
    end
  end
end
