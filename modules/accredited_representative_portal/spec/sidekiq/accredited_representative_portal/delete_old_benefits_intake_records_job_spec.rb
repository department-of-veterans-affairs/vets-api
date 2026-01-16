# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::DeleteOldBenefitsIntakeRecordsJob, type: :job do
  subject(:job) { described_class.new }

  let(:statsd_key_prefix) { described_class::STATSD_KEY_PREFIX }

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
        expect(AccreditedRepresentativePortal::SavedClaim::BenefitsIntake).not_to receive(:where)
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
        let!(:dependency_old) do
          create(:saved_claim_benefits_intake, delete_date: 61.days.ago)
        end

        let!(:disability_old) do
          create(:saved_claim_benefits_intake,
                 type: 'AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DisabilityClaim',
                 delete_date: 70.days.ago)
        end

        let!(:dependency_recent) do
          create(:saved_claim_benefits_intake, delete_date: 10.days.ago)
        end

        let!(:disability_recent) do
          create(:saved_claim_benefits_intake,
                 type: 'AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DisabilityClaim',
                 delete_date: 5.days.ago)
        end

        it 'deletes only records older than 60 days' do
          expect { job.perform }.to change(
            AccreditedRepresentativePortal::SavedClaim::BenefitsIntake, :count
          ).by(-2)

          expect(
            AccreditedRepresentativePortal::SavedClaim::BenefitsIntake.exists?(dependency_recent.id)
          ).to be(true)

          expect(
            AccreditedRepresentativePortal::SavedClaim::BenefitsIntake.exists?(disability_recent.id)
          ).to be(true)
        end

        it 'increments StatsD with the number of deleted records' do
          job.perform

          expect(StatsD).to have_received(:increment)
            .with("#{statsd_key_prefix}.count", 2)
        end

        it 'logs a single info message with the deleted count' do
          job.perform

          expect(Rails.logger).to have_received(:info)
            .with(/DeleteOldBenefitsIntakeRecordsJob deleted 2 old BenefitsIntake records/)
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
            AccreditedRepresentativePortal::SavedClaim::BenefitsIntake, :count
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
            .with(/DeleteOldBenefitsIntakeRecordsJob perform exception: ActiveRecord::ActiveRecordError boom/)

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
end
