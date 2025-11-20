# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::SubmissionJob, type: :job do
  let(:user) { create(:user) }
  let(:user_identifier) { HealthCareApplication.get_user_identifier(user) }
  let(:health_care_application) { create(:health_care_application) }
  let(:form) do
    {
      foo: true,
      email: 'foo@example.com',
      veteranFullName: {
        first: 'first',
        last: 'last'
      }
    }.deep_stringify_keys
  end
  let(:encrypted_form) { HealthCareApplication::LOCKBOX.encrypt(form.to_json) }
  let(:google_analytics_client_id) { '123456789' }
  let(:result) do
    {
      formSubmissionId: 123,
      timestamp: '2017-08-03 22:02:18 -0400'
    }
  end
  let(:hca_service) { double }

  describe '#notify' do
    subject(:notify) { described_class.new.notify(params) }

    let(:tags) { ["health_care_application_id:#{health_care_application.id}"] }
    let(:args) do
      [
        user_identifier,
        encrypted_form,
        health_care_application.id,
        google_analytics_client_id
      ]
    end

    before { allow(StatsD).to receive(:increment) }

    context 'retry_count is not 9' do
      let(:params) { { 'retry_count' => 5, 'args' => args } }

      it 'does not increment failed_ten_retries statsd' do
        expect(StatsD).not_to receive(:increment).with('api.1010ez.async.failed_ten_retries', tags:)
        notify
      end
    end

    context 'retry_count is 9' do
      let(:params) { { 'retry_count' => 9, 'args' => args } }

      it 'increments failed_ten_retries statsd' do
        expect(StatsD).to receive(:increment).with('api.1010ez.async.failed_ten_retries', tags:)
        notify
      end
    end
  end

  it 'returns an array of integers from retry_limits_for_notification' do
    expect(described_class.new.retry_limits_for_notification).to eq([10])
  end

  describe 'when job has failed' do
    let(:msg) do
      {
        'args' => [nil, encrypted_form, health_care_application.id, 'google_analytics_client_id']
      }
    end

    it 'passes unencrypted form to health_care_application' do
      expect_any_instance_of(HealthCareApplication).to receive(:update!).with(
        state: 'failed',
        form: form.to_json,
        google_analytics_client_id: 'google_analytics_client_id'
      )
      described_class.new.sidekiq_retries_exhausted_block.call(msg)
    end

    it 'sets the health_care_application state to failed' do
      described_class.new.sidekiq_retries_exhausted_block.call(msg)
      expect(health_care_application.reload.state).to eq('failed')
    end
  end

  describe '#perform' do
    subject do
      described_class.new.perform(
        user_identifier,
        encrypted_form,
        health_care_application.id,
        google_analytics_client_id
      )
    end

    before do
      expect(HCA::Service).to receive(:new).with(user_identifier).once.and_return(hca_service)
    end

    context 'when submission has an error' do
      let(:error) { Common::Client::Errors::HTTPError }

      before do
        expect(hca_service).to receive(:submit_form).with(form).once.and_raise(error)
      end

      it 'sets the health_care_application state to error' do
        expect { subject }.to raise_error(error)
        health_care_application.reload

        expect(health_care_application.state).to eq('error')
      end

      context 'with a validation error' do
        let(:error) { HCA::SOAPParser::ValidationError }

        it 'passes unencrypted form to health_care_application' do
          expect_any_instance_of(HealthCareApplication).to receive(:update!).with(
            state: 'failed',
            form: form.to_json,
            google_analytics_client_id:
          )
          subject
        end

        it 'sets the health_care_application state to failed' do
          subject
          expect(health_care_application.reload.state).to eq('failed')
        end

        it 'creates a pii log' do
          subject

          log = PersonalInformationLog.where(error_class: 'HCA::SOAPParser::ValidationError').last
          expect(log.data['form']).to eq(form)
        end

        it 'increments statsd' do
          expect { subject }.to trigger_statsd_increment('api.1010ez.enrollment_system_validation_error')
        end
      end
    end

    context 'with a successful submission' do
      before do
        expect(hca_service).to receive(:submit_form).with(form).once.and_return(result)
        expect(Rails.logger).to receive(:info).with("[10-10EZ] - SubmissionID=#{result[:formSubmissionId]}")
      end

      it 'calls the service and save the results' do
        subject
        health_care_application.reload

        expect(health_care_application.success?).to be(true)
        expect(health_care_application.form_submission_id).to eq(result[:formSubmissionId])
        expect(health_care_application.timestamp).to eq(result[:timestamp])
      end
    end
  end
end
