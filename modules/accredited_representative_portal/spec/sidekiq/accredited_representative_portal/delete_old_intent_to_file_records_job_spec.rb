# frozen_string_literal: true

require 'rails_helper'

# Top-level test subclass: avoids Lint/ConstantDefinitionInBlock
class TestDeleteOldIntentToFileRecordsJob < AccreditedRepresentativePortal::DeleteOldIntentToFileRecordsJob
  def enabled?
    true
  end

  def scope
    AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::IntentToFile.all
  end

  def statsd_key_prefix
    'test.prefix'
  end

  def log_label
    'IntentToFile'
  end
end

RSpec.describe AccreditedRepresentativePortal::DeleteOldIntentToFileRecordsJob, type: :job do
  subject(:job) { TestDeleteOldIntentToFileRecordsJob.new }

  let(:statsd_key_prefix) { job.statsd_key_prefix }

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe '#perform' do
    context 'when the feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_delete_benefits_intake)
          .and_return(false)
      end

      it 'does nothing' do
        expect(AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::IntentToFile).not_to receive(:where)
        job.perform
      end
    end

    context 'when the feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_delete_benefits_intake)
          .and_return(true)
      end

      context 'when there are records older than 60 days' do
        let!(:old_record1) { create(:saved_claim_intent_to_file, :old) }
        let!(:old_record2) { create(:saved_claim_intent_to_file, :old) }
        let!(:recent_record1) { create(:saved_claim_intent_to_file, :recent) }
        let!(:recent_record2) { create(:saved_claim_intent_to_file, :recent) }

        it 'deletes only records older than 60 days' do
          expect { job.perform }.to change(
            AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::IntentToFile, :count
          ).by(-2)

          expect(
            AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::IntentToFile.exists?(recent_record1.id)
          ).to be(true)

          expect(
            AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::IntentToFile.exists?(recent_record2.id)
          ).to be(true)
        end

        it 'increments StatsD with the number of deleted records' do
          job.perform
          expect(StatsD).to have_received(:increment).with("#{statsd_key_prefix}.count", 2)
        end

        it 'logs a single info message with the deleted count' do
          job.perform
          expect(Rails.logger).to have_received(:info)
            .with(/DeleteOldIntentToFileRecordsJob deleted 2 old IntentToFile records/)
        end
      end

      context 'when no records qualify for deletion' do
        let!(:recent_record1) { create(:saved_claim_intent_to_file, :recent) }
        let!(:recent_record2) { create(:saved_claim_intent_to_file, :recent) }

        it 'does not delete anything' do
          expect { job.perform }.not_to change(
            AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::IntentToFile, :count
          )
        end

        it 'increments StatsD with zero deletions' do
          job.perform
          expect(StatsD).to have_received(:increment).with("#{statsd_key_prefix}.count", 0)
        end
      end

      context 'when an exception occurs during deletion' do
        let(:exception) { ActiveRecord::ActiveRecordError.new('boom') }
        let(:slack_messenger) { instance_double(VBADocuments::Slack::Messenger, notify!: true) }

        it 'logs the error and increments StatsD error metric' do
          # Create a job with a scope double that raises
          relation = double('relation')
          allow(relation).to receive(:where).and_raise(exception)

          job_with_exception = TestDeleteOldIntentToFileRecordsJob.new
          allow(job_with_exception).to receive(:scope).and_return(relation)
          allow(VBADocuments::Slack::Messenger).to receive(:new).and_return(slack_messenger)

          job_with_exception.perform

          expect(Rails.logger).to have_received(:error)
            .with(/DeleteOldIntentToFileRecordsJob perform exception: ActiveRecord::ActiveRecordError boom/)

          expect(StatsD).to have_received(:increment)
            .with("#{job_with_exception.statsd_key_prefix}.error")
        end

        it 'sends a single Slack alert with the exception info' do
          relation = double('relation')
          allow(relation).to receive(:where).and_raise(exception)

          job_with_exception = TestDeleteOldIntentToFileRecordsJob.new
          allow(job_with_exception).to receive(:scope).and_return(relation)
          allow(VBADocuments::Slack::Messenger).to receive(:new).and_return(slack_messenger)

          job_with_exception.perform
          expect(slack_messenger).to have_received(:notify!).once
        end

        it 'does not raise the exception' do
          relation = double('relation')
          allow(relation).to receive(:where).and_raise(exception)

          job_with_exception = TestDeleteOldIntentToFileRecordsJob.new
          allow(job_with_exception).to receive(:scope).and_return(relation)
          allow(VBADocuments::Slack::Messenger).to receive(:new).and_return(slack_messenger)

          expect { job_with_exception.perform }.not_to raise_error
        end
      end
    end
  end
end
