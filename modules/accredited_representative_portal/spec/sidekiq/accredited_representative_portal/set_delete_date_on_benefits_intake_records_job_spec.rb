# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::SetDeleteDateOnBenefitsIntakeRecordsJob, type: :job do
  subject(:job) { described_class.new }

  let(:statsd_key_prefix) { described_class::STATSD_KEY_PREFIX }

  let!(:pending_form_submission) { create(:form_submission, :pending) }
  let!(:pending_saved_claim) do
    create(:saved_claim_benefits_intake, form_submissions: [pending_form_submission])
  end

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe '#perform' do
    context 'when there are records older than 60 days' do
      let!(:success_form_submission) { create(:form_submission, :success) }
      let!(:vbms_form_submission_attempt) do
        create(:form_submission_attempt, :vbms, form_submission: success_form_submission)
      end
      let!(:vbms_saved_claim) do
        create(:saved_claim_benefits_intake, form_submissions: [success_form_submission.reload])
      end

      it 'marks only records that are in vbms for deletion' do
        expect { job.perform }.to change(
          AccreditedRepresentativePortal::SavedClaim::BenefitsIntake.where.not(delete_date: nil),
          :count
        ).by(1)
      end

      it 'increments StatsD with the number of records marked deleted' do
        job.perform

        expect(StatsD).to have_received(:increment)
          .with("#{statsd_key_prefix}.count", 1)
      end

      it 'logs a single info message with the marked deleted count' do
        job.perform

        expect(Rails.logger).to have_received(:info)
          .with(/SetDeleteDateOnBenefitsIntakeRecordsJob marked 1 old BenefitsIntake records for deletion on/)
      end
    end

    context 'when no records qualify for deletion' do
      let!(:dependency_recent) { create(:saved_claim_benefits_intake, delete_date: 5.days.ago) }
      let!(:disability_recent) do
        create(:saved_claim_benefits_intake,
               type: 'AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DisabilityClaim',
               delete_date: 10.days.ago)
      end

      it 'does not delete anything' do
        expect { job.perform }.not_to change(
          AccreditedRepresentativePortal::SavedClaim::BenefitsIntake.where(delete_date: nil),
          :count
        )
      end

      it 'increments StatsD with zero deletions' do
        job.perform

        expect(StatsD).to have_received(:increment)
          .with("#{statsd_key_prefix}.count", 0)
      end
    end

    context 'when an exception occurs during deletion' do
      let(:exception) { ActiveRecord::ActiveRecordError.new('boom') }

      let(:slack_messenger) do
        instance_double(VBADocuments::Slack::Messenger, notify!: true)
      end

      before do
        allow(AccreditedRepresentativePortal::SavedClaim::BenefitsIntake)
          .to receive(:where).and_raise(exception)

        allow(VBADocuments::Slack::Messenger)
          .to receive(:new)
          .and_return(slack_messenger)
      end

      it 'logs the error and increments StatsD error metric' do
        job.perform

        expect(Rails.logger).to have_received(:error)
          .with(/SetDeleteDateOnBenefitsIntakeRecordsJob perform exception: ActiveRecord::ActiveRecordError boom/)

        expect(StatsD).to have_received(:increment)
          .with("#{statsd_key_prefix}.error")
      end

      it 'sends a single Slack alert with the exception info' do
        job.perform

        expect(slack_messenger).to have_received(:notify!).once
      end

      it 'does not raise the exception' do
        expect { job.perform }.not_to raise_error
      end
    end
  end
end
