# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::DailyStuckRecordsReport, type: :job do
  include FixtureHelpers

  before { Sidekiq::Job.clear_all }

  describe '#perform' do
    let(:stuck_records) do
      [
        create(:higher_level_review_v2, status: 'pending'),
        create(:notice_of_disagreement_v2, status: 'submitting'),
        create(:supplemental_claim, status: 'submitting')
      ]
    end

    let!(:other_records) do
      [
        create(:higher_level_review_v2, status: 'pending'),
        create(:notice_of_disagreement_v2, status: 'submitting'),
        create(:supplemental_claim, status: 'submitted')
      ]
    end

    context 'when enabled' do
      before { Flipper.enable :decision_review_daily_stuck_records_report_enabled } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it_behaves_like 'a monitored worker'

      it 'does not send a message when no stuck records are found' do
        expect(AppealsApi::Slack::Messager).not_to receive(:new)
        with_settings(Settings, vsp_environment: 'staging') do
          described_class.new.perform
        end
      end

      it 'selects only stuck records which have a "pending" or "submitting" status and are older than 2 hours' do
        Timecop.freeze do
          stale_date = 3.hours.ago
          # rubocop:disable Rails/SkipsModelValidations
          stuck_records.each_with_index do |record, i|
            record.update_column(:created_at, stale_date - i.minutes)
            record
          end
          other_records.last.update_columns(created_at: stale_date) # Should not be selected
          # rubocop:enable Rails/SkipsModelValidations

          expected_data = stuck_records.map do |record|
            hash_including(
              # Skipping :created_at here since `ActiveSupport::TimeWithZone`s are too hard to compare in this context
              record.slice(:id, :status).symbolize_keys.merge({ record_type: record.class.name.demodulize })
            )
          end

          allow(AppealsApi::Slack::StuckRecordNotification).to receive(:new).and_call_original
          allow(Faraday).to receive(:post)

          with_settings(Settings, vsp_environment: 'staging') do
            described_class.new.perform
          end

          expect(AppealsApi::Slack::StuckRecordNotification)
            .to have_received(:new).with(match_array(expected_data))
        end
      end
    end

    context 'when disabled' do
      before { Flipper.disable :decision_review_daily_stuck_records_report_enabled } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'does nothing' do
        expect(AppealsApi::Slack::Messager).not_to receive(:new)
        described_class.new.perform
      end
    end
  end
end
