# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.inline! # run jobs immediately for testing

RSpec.describe AccreditedRepresentativePortal::DeleteOldBenefitsIntakeRecordsJob, type: :job do
  let(:feature_flag) { :delete_old_benefits_intake_records_job_enabled }
  let!(:old_record) do
    create(
      :accredited_representative_portal_saved_claim_benefits_intake,
      created_at: 61.days.ago
    )
  end
  let!(:new_record) do
    create(
      :accredited_representative_portal_saved_claim_benefits_intake,
      created_at: 30.days.ago
    )
  end

  before do
    allow(Flipper).to receive(:enabled?)
      .with(feature_flag)
      .and_return(feature_flag_enabled)

    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:info)
    allow(Slack::Notifier).to receive(:notify)
  end

  context 'when feature flag is enabled' do
    let(:feature_flag_enabled) { true }

    it 'deletes records older than 60 days' do
      expect do
        described_class.new.perform
      end.to change(
        AccreditedRepresentativePortal::SavedClaim::BenefitsIntake,
        :count
      ).by(-1)

      expect(
        AccreditedRepresentativePortal::SavedClaim::BenefitsIntake.exists?(old_record.id)
      ).to be false
    end

    it 'does not delete newer records' do
      described_class.new.perform

      expect(
        AccreditedRepresentativePortal::SavedClaim::BenefitsIntake.exists?(new_record.id)
      ).to be true
    end

    it 'increments StatsD with the number of deleted records' do
      described_class.new.perform

      expect(StatsD).to have_received(:increment).with(
        'worker.accredited_representative_portal.delete_old_benefits_intake_records.count',
        1
      )
    end
  end

  context 'when feature flag is disabled' do
    let(:feature_flag_enabled) { false }

    it 'does not delete any records' do
      expect do
        described_class.new.perform
      end.not_to change(
        AccreditedRepresentativePortal::SavedClaim::BenefitsIntake,
        :count
      )
    end
  end

  context 'when an error occurs' do
    let(:feature_flag_enabled) { true }

    before do
      allow(
        AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
      ).to receive(:destroy_all).and_raise(StandardError.new('boom'))
    end

    it 'logs the error and increments StatsD error' do
      described_class.new.perform

      expect(StatsD).to have_received(:increment).with(
        'worker.accredited_representative_portal.delete_old_benefits_intake_records.error'
      )

      expect(Rails.logger).to have_received(:error).with(
        'AccreditedRepresentativePortal::DeleteOldBenefitsIntakeRecordsJob perform exception: ' \
        'StandardError boom'
      )
    end

    it 'sends a Slack alert when the job fails' do
      described_class.new.perform

      expect(Slack::Notifier).to have_received(:notify).with(
        a_string_including(
          'DeleteOldBenefitsIntakeRecordsJob failed',
          'StandardError',
          'boom'
        )
      )
    end

    it 'does not crash if Slack notification fails' do
      allow(Slack::Notifier).to receive(:notify)
        .and_raise(StandardError.new('slack down'))

      described_class.new.perform

      expect(Rails.logger).to have_received(:error).with(
        a_string_including('Failed to send Slack alert')
      )
    end
  end
end