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
        expect(
          AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
        ).not_to receive(:where)

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
            .with(
              /DeleteOldBenefitsIntakeRecordsJob deleted 2 old BenefitsIntake records/
            )
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
        let(:exception) { StandardError.new('boom') }

        before do
          allow(
            AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
          ).to receive(:where).and_raise(exception)
        end

        context 'when Slack::Notifier is defined' do
          before do
            stub_const('Slack::Notifier', Class.new do
              def self.notify(_message); end
            end)
            allow(Slack::Notifier).to receive(:notify)
          end

          it 'logs the error and increments StatsD error metric' do
            job.perform

            expect(Rails.logger).to have_received(:error)
              .with(/DeleteOldBenefitsIntakeRecordsJob perform exception: StandardError boom/)

            expect(StatsD).to have_received(:increment)
              .with("#{statsd_key_prefix}.error")
          end

          it 'sends a single Slack alert with the exception info' do
            job.perform

            expect(Slack::Notifier).to have_received(:notify)
              .with(
                '[ALERT] AccreditedRepresentativePortal::DeleteOldBenefitsIntakeRecordsJob ' \
                'failed: StandardError - boom'
              )
          end

          it 'does not log a Slack warning' do
            job.perform

            expect(Rails.logger).not_to have_received(:warn)
          end

          it 'does not raise the exception' do
            expect { job.perform }.not_to raise_error
          end
        end

        context 'when Slack::Notifier is not defined' do
          it 'logs a single warning with the exception info and does not raise' do
            job.perform

            expect(Rails.logger).to have_received(:warn)
              .with(/Slack::Notifier not defined; skipping StandardError boom/)
          end

          it 'does not raise the exception' do
            expect { job.perform }.not_to raise_error
          end
        end
      end
    end
  end
end
