# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::SubmissionJob, type: :job do
  let(:user) { create(:user) }
  let(:health_care_application) { create(:health_care_application) }
  let(:form) { { foo: true } }
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
        'args' => [nil, nil, health_care_application.id]
      }
    end

    it 'should set the health_care_application state to failed' do
      described_class.new.sidekiq_retries_exhausted_block.call(msg)

      expect(health_care_application.reload.state).to eq('failed')
    end
  end

  describe '#perform' do
    before do
      # this line is needed to make stub in next line work because the found user
      # is not == to another instance of itself
      expect(User).to receive(:find).with(user.uuid).once.and_return(user)
      expect(HCA::Service).to receive(:new).with(user).once.and_return(hca_service)
    end

    subject do
      described_class.new.perform(user.uuid, form, health_care_application.id)
    end

    context 'when submission has an error' do
      let(:error) { Common::Client::Errors::HTTPError }

      before do
        expect(hca_service).to receive(:submit_form).with(form).once.and_raise(error)
      end

      context 'with a validation error' do
        let(:error) { HCA::SOAPParser::ValidationError }

        it 'should set the record to failed' do
          subject

          health_care_application.reload

          expect(health_care_application.state).to eq('failed')
        end
      end

      it 'should set the health_care_application state to error' do
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

      it 'should call the service and save the results' do
        subject
        health_care_application.reload

        expect(health_care_application.success?).to eq(true)
        expect(health_care_application.form_submission_id).to eq(result[:formSubmissionId])
        expect(health_care_application.timestamp).to eq(result[:timestamp])
      end
    end
  end
end
