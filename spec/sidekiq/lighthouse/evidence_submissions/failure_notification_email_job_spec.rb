# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/service'
require 'lighthouse/benefits_documents/utilities/helpers'

RSpec.describe Lighthouse::EvidenceSubmissions::FailureNotificationEmailJob, type: :job do
  subject { described_class }

  let(:notification_id) { SecureRandom.uuid }
  let(:vanotify_service) do
    service = instance_double(VaNotify::Service)

    response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
    allow(service).to receive(:send_email).and_return(response)

    service
  end

  context 'when there are no FAILED records' do
    it 'doesnt send anything' do
      expect(EvidenceSubmission).not_to receive(:update)
      expect(vanotify_service).not_to receive(:send_email)
      expect(EvidenceSubmission.va_notify_email_queued.length).to equal(0)
      subject.new.perform
    end
  end

  context 'when there is a FAILED record with a va_notify_date' do
    before do
      allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
      create(:bd_evidence_submission_failed_va_notify_email_enqueued)
    end

    it 'doesnt update an evidence submission record or queue failure email' do
      expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
      subject.new.perform
      expect(vanotify_service).not_to receive(:send_email)
      # This is still 1 since is has already been queued
      expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
    end
  end

  context 'when the FAILED record is for EVSS and doesnt have a va_notify_date' do
    context 'when an error occurs' do
      before do
        allow(VaNotify::Service).to receive(:new).and_raise(StandardError)
        allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      let!(:evidence_submission_failed) { create(:bd_evss_evidence_submission_failed_type1_error) }
      let(:error_message) { "#{evidence_submission_failed.job_class} va notify failure email errored" }
      let(:tags) { ['service:claim-status', "function: #{error_message}"] }

      it 'handles the error and increments the statsd metric' do
        expect(EvidenceSubmission.count).to eq(1)
        expect(EvidenceSubmission.va_notify_email_queued.length).to eq(0)
        expect(vanotify_service).not_to receive(:send_email)
        expect(Rails.logger)
          .to receive(:error)
          .with(error_message, { message: 'StandardError' })
        expect(StatsD).to receive(:increment).with('silent_failure', tags:)
        subject.new.perform
      end
    end

    context 'when no error occurs' do
      let(:tags) { ['service:claim-status', "function: #{message}"] }
      let(:message) { "#{evidence_submission_failed.job_class} va notify failure email queued" }
      let!(:evidence_submission_failed) { create(:bd_evss_evidence_submission_failed_type1_error) }
      let(:personalisation) do
        BenefitsDocuments::Utilities::Helpers.create_personalisation_from_upload(evidence_submission_failed)
      end
      let(:send_email_params) do
        {
          recipient_identifier: {
            id_value: evidence_submission_failed.user_account.icn,
            id_type: 'ICN'
          },
          template_id: Settings.vanotify.services.benefits_management_tools
                               .template_id.evidence_submission_failure_email,
          personalisation:
        }
      end

      before do
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
        allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
      end

      it 'successfully enqueues a failure notification mailer to send to the veteran' do
        expect(EvidenceSubmission.count).to eq(1)
        expect(EvidenceSubmission.va_notify_email_not_queued.length).to eq(1)
        expect(vanotify_service).to receive(:send_email).with(send_email_params)
        expect(evidence_submission_failed).to receive(:update).and_call_original
        expect(Rails.logger).to receive(:info).with(message)
        subject.new.perform
        expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
      end
    end
  end

  context 'when the FAILED record is for Lighthouse type 1 error and doesnt have a va_notify_date' do
    context 'when an error occurs' do
      before do
        allow(VaNotify::Service).to receive(:new).and_raise(StandardError)
        allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      let!(:evidence_submission_failed) { create(:bd_lh_evidence_submission_failed_type1_error) }
      let(:error_message) { "#{evidence_submission_failed.job_class} va notify failure email errored" }
      let(:tags) { ['service:claim-status', "function: #{error_message}"] }

      it 'handles the error and increments the statsd metric' do
        expect(EvidenceSubmission.count).to eq(1)
        expect(EvidenceSubmission.va_notify_email_queued.length).to eq(0)
        expect(vanotify_service).not_to receive(:send_email)
        expect(Rails.logger)
          .to receive(:error)
          .with(error_message, { message: 'StandardError' })
        expect(StatsD).to receive(:increment).with('silent_failure', tags:)
        subject.new.perform
      end
    end

    context 'when no error occurs' do
      let(:tags) { ['service:claim-status', "function: #{message}"] }
      let(:message) { "#{evidence_submission_failed.job_class} va notify failure email queued" }
      let!(:evidence_submission_failed) { create(:bd_lh_evidence_submission_failed_type1_error) }
      let(:personalisation) do
        BenefitsDocuments::Utilities::Helpers.create_personalisation_from_upload(evidence_submission_failed)
      end
      let(:send_email_params) do
        {
          recipient_identifier: {
            id_value: evidence_submission_failed.user_account.icn,
            id_type: 'ICN'
          },
          template_id: Settings.vanotify.services.benefits_management_tools
                               .template_id.evidence_submission_failure_email,
          personalisation:
        }
      end

      before do
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
        allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
      end

      it 'successfully enqueues a failure notification mailer to send to the veteran' do
        expect(EvidenceSubmission.count).to eq(1)
        expect(EvidenceSubmission.va_notify_email_not_queued.length).to eq(1)
        expect(vanotify_service).to receive(:send_email).with(send_email_params)
        expect(evidence_submission_failed).to receive(:update).and_call_original
        expect(Rails.logger).to receive(:info).with(message)
        subject.new.perform
        expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
        evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_failed.id)
        expect(evidence_submission.va_notify_date).not_to be_nil
      end
    end
  end

  context 'when the FAILED record is for Lighthouse type 2 error and doesnt have a va_notify_date' do
    context 'when an error occurs' do
      before do
        allow(VaNotify::Service).to receive(:new).and_raise(StandardError)
        allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      let!(:evidence_submission_failed) { create(:bd_lh_evidence_submission_failed_type2_error) }
      let(:error_message) { "#{evidence_submission_failed.job_class} va notify failure email errored" }
      let(:tags) { ['service:claim-status', "function: #{error_message}"] }

      it 'handles the error and increments the statsd metric' do
        expect(EvidenceSubmission.count).to eq(1)
        expect(EvidenceSubmission.va_notify_email_queued.length).to eq(0)
        expect(vanotify_service).not_to receive(:send_email)
        expect(Rails.logger)
          .to receive(:error)
          .with(error_message, { message: 'StandardError' })
        expect(StatsD).to receive(:increment).with('silent_failure', tags:)
        subject.new.perform
      end
    end

    context 'when no error occurs' do
      let(:tags) { ['service:claim-status', "function: #{message}"] }
      let(:message) { "#{evidence_submission_failed.job_class} va notify failure email queued" }
      let!(:evidence_submission_failed) { create(:bd_lh_evidence_submission_failed_type2_error) }
      let(:personalisation) do
        BenefitsDocuments::Utilities::Helpers.create_personalisation_from_upload(evidence_submission_failed)
      end
      let(:send_email_params) do
        {
          recipient_identifier: {
            id_value: evidence_submission_failed.user_account.icn,
            id_type: 'ICN'
          },
          template_id: Settings.vanotify.services.benefits_management_tools
                               .template_id.evidence_submission_failure_email,
          personalisation:
        }
      end

      before do
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
        allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed])
        allow(Rails.logger).to receive(:info)
        allow(StatsD).to receive(:increment)
      end

      it 'successfully enqueues a failure notification mailer to send to the veteran' do
        expect(EvidenceSubmission.count).to eq(1)
        expect(EvidenceSubmission.va_notify_email_not_queued.length).to eq(1)
        expect(vanotify_service).to receive(:send_email).with(send_email_params)
        expect(evidence_submission_failed).to receive(:update).and_call_original
        expect(Rails.logger).to receive(:info).with(message)
        subject.new.perform
        expect(EvidenceSubmission.va_notify_email_queued.length).to eq(1)
        evidence_submission = EvidenceSubmission.find_by(id: evidence_submission_failed.id)
        expect(evidence_submission.va_notify_date).not_to be_nil
      end
    end
  end

  context 'when there are multiple FAILED records without a va_notify_date' do
    let(:message1) { "#{evidence_submission_failed1.job_class} va notify failure email queued" }
    let(:message2) { "#{evidence_submission_failed2.job_class} va notify failure email queued" }
    let(:message3) { "#{evidence_submission_failed3.job_class} va notify failure email queued" }

    let!(:evidence_submission_failed1) { create(:bd_lh_evidence_submission_failed_type1_error) }
    let!(:evidence_submission_failed2) { create(:bd_lh_evidence_submission_failed_type2_error) }
    let!(:evidence_submission_failed3) { create(:bd_evss_evidence_submission_failed_type1_error) }

    before do
      allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
      allow(EvidenceSubmission).to receive(:va_notify_email_not_queued).and_return([evidence_submission_failed1,
                                                                                    evidence_submission_failed2,
                                                                                    evidence_submission_failed3])
      allow(Rails.logger).to receive(:info)
      allow(StatsD).to receive(:increment)
    end

    it 'successfully enqueues a failure notification mailer to send to the veteran' do
      expect(EvidenceSubmission.count).to eq(3)
      expect(EvidenceSubmission.va_notify_email_not_queued.length).to eq(3)
      expect(vanotify_service).to receive(:send_email)

      expect(evidence_submission_failed1).to receive(:update).and_call_original
      expect(evidence_submission_failed2).to receive(:update).and_call_original
      expect(evidence_submission_failed3).to receive(:update).and_call_original

      expect(Rails.logger).to receive(:info).with(message1)
      expect(Rails.logger).to receive(:info).with(message2)
      expect(Rails.logger).to receive(:info).with(message3)

      subject.new.perform
      expect(EvidenceSubmission.va_notify_email_queued.length).to eq(3)
    end
  end
end
