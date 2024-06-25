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
  let(:result) do
    {
      formSubmissionId: 123,
      timestamp: '2017-08-03 22:02:18 -0400'
    }
  end
  let(:hca_service) { double }

  describe 'when job has run out of retries' do
    subject do
      described_class.new.sidekiq_retries_exhausted_block.call(msg, nil)
    end

    let(:msg) do
      {
        'args' => [nil, encrypted_form, health_care_application.id, 'google_analytics_client_id']
      }
    end

    it 'sets attributes on health_care_appplication instance' do
      expect(HealthCareApplication).to receive(:find)
        .with(health_care_application.id)
        .and_return(health_care_application)
      expect(health_care_application).to receive(:save).with(validate: false).and_return(true)

      subject

      expect(health_care_application.form).to eq(form.to_json)
      expect(health_care_application.google_analytics_client_id).to eq('google_analytics_client_id')
    end

    it 'persists the updated state to failed on health_care_application' do
      subject

      expect(health_care_application.reload.state).to eq('failed')
    end
  end

  describe '#perform' do
    subject do
      described_class.new.perform(user_identifier, encrypted_form, health_care_application.id, '123456789')
    end

    before do
      expect(HCA::Service).to receive(:new).with(user_identifier).once.and_return(hca_service)
    end

    context 'when submission has an error' do
      let(:error) { Common::Client::Errors::HTTPError }

      before do
        expect(hca_service).to receive(:submit_form).with(form).once.and_raise(error)
      end

      context 'with a validation error' do
        let(:error) { HCA::SOAPParser::ValidationError }

        it 'sets the record to failed' do
          subject

          health_care_application.reload

          expect(health_care_application.state).to eq('failed')
        end

        it 'creates a pii log' do
          subject

          log = PersonalInformationLog.where(error_class: 'HCA::SOAPParser::ValidationError').last
          expect(log.data['form']).to eq(form)
        end
      end

      it 'sets the health_care_application state to error' do
        expect { subject }.to raise_error(error)
        health_care_application.reload

        expect(health_care_application.state).to eq('error')
      end
    end

    context 'with a successful submission' do
      before do
        expect(hca_service).to receive(:submit_form).with(form).once.and_return(result)
        expect(Rails.logger).to receive(:info).with("SubmissionID=#{result[:formSubmissionId]}")
      end

      it 'calls the service and save the results' do
        subject
        health_care_application.reload

        expect(health_care_application.success?).to eq(true)
        expect(health_care_application.form_submission_id).to eq(result[:formSubmissionId])
        expect(health_care_application.timestamp).to eq(result[:timestamp])
      end
    end
  end
end
