# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::EzrSubmissionJob, type: :job do
  let(:user) { create(:evss_user, :loa3, icn: '1013032368V065534') }
  let(:form) do
    get_fixture('form1010_ezr/valid_form')
  end
  let(:encrypted_form) do
    HealthCareApplication::LOCKBOX.encrypt(form.to_json)
  end
  let(:ezr_service) { double }

  describe 'when job has failed' do
    let(:msg) do
      {
        'args' => [encrypted_form, nil]
      }
    end

    it 'passes unencrypted form to 1010ezr service' do
      expect_any_instance_of(Form1010Ezr::Service).to receive(:log_submission_failure).with(
        form
      )
      described_class.new.sidekiq_retries_exhausted_block.call(msg)
    end
  end

  describe '#perform' do
    subject do
      described_class.new.perform(encrypted_form, user.uuid)
    end

    before do
      allow(User).to receive(:find).with(user.uuid).and_return(user)
      allow(Form1010Ezr::Service).to receive(:new).with(user).once.and_return(ezr_service)
    end

    context 'when submission has an error' do
      context 'with a validation error' do
        let(:error) { HCA::SOAPParser::ValidationError }

        it 'logs the submission failure and logs exception to sentry' do
          allow(ezr_service).to receive(:submit_sync).with(form).once.and_raise(error)
          # Because we're calling the 'log_submission_failure' method from a new instance
          # of the 'Form1010Ezr::Service', we need to stub out a new instance of the service
          allow(Form1010Ezr::Service).to receive(:new).with(nil).once.and_return(ezr_service)

          expect_any_instance_of(HCA::EzrSubmissionJob).to receive(:log_exception_to_sentry).with(error)
          expect(ezr_service).to receive(:log_submission_failure).with(
            form
          )

          subject
        end
      end

      context 'with any other error' do
        let(:error) { Common::Client::Errors::HTTPError }

        it 'logs the retry' do
          allow(ezr_service).to receive(:submit_sync).with(form).once.and_raise(error)

          expect { subject }.to trigger_statsd_increment(
            'api.1010ezr.async.retries'
          ).and raise_error(error)
        end
      end
    end

    context 'with a successful submission' do
      it 'calls the service' do
        expect(ezr_service).to receive(:submit_sync).with(form)

        subject
      end
    end
  end
end
