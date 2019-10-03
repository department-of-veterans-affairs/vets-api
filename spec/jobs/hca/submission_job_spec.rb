# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::SubmissionJob, type: :job do
  let(:user) { create(:user) }
  let(:user_identifier) { HealthCareApplication.get_user_identifier(user) }
  let(:health_care_application) { create(:health_care_application) }
  let(:form) { { foo: true, email: 'foo@example.com' } }
  let(:result) do
    {
      formSubmissionId: 123,
      timestamp: '2017-08-03 22:02:18 -0400'
    }
  end
  let(:hca_service) do
    double
  end

  describe 'when job has failed' do
    let(:msg) do
      {
        'args' => [nil, form, health_care_application.id]
      }
    end

    it 'sets the health_care_application state to failed' do
      described_class.new.sidekiq_retries_exhausted_block.call(msg)
      expect(health_care_application.reload.state).to eq('failed')
    end
  end

  describe '#perform' do
    subject do
      described_class.new.perform(user_identifier, form, health_care_application.id, '123456789')
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

          log = PersonalInformationLog.last
          expect(log.data['form']).to eq(form.stringify_keys)
          expect(log.error_class).to eq('HCA::SOAPParser::ValidationError')
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
