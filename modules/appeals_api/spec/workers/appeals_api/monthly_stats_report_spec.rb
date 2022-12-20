# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::MonthlyStatsReport do
  include FixtureHelpers

  before { Sidekiq::Worker.clear_all }

  it_behaves_like 'a monitored worker'

  describe '#perform' do
    describe 'when enabled' do
      let(:end_date) { Time.utc(2022, 1, 2, 3, 4, 5) }
      let(:recipients) { %w[someone@somewhere.tld] }

      before do
        Flipper.enable(:decision_review_monthly_stats_report_enabled)
      end

      it 'does not build a report without recipients' do
        with_settings(Settings.modules_appeals_api.reports.monthly_stats, recipients: []) do
          expect(AppealsApi::StatsReportMailer).not_to receive(:build)

          described_class.new.perform
        end
      end

      it 'sends a stats report for the past month to the recipients by default' do
        Timecop.freeze(end_date) do
          with_settings(Settings.modules_appeals_api.reports.monthly_stats, recipients: recipients) do
            expect(AppealsApi::StatsReportMailer).to receive(:build).with(
              date_from: (end_date - 1.month).beginning_of_day,
              date_to: end_date.beginning_of_day,
              recipients: recipients,
              subject: 'Lighthouse appeals stats report for month starting 2021-12-02'
            ).and_call_original

            described_class.new.perform
          end
        end
      end
    end

    describe 'disabled' do
      it 'is disabled unless the dedicated flipper setting is enabled' do
        Flipper.disable(:decision_review_monthly_stats_report_enabled)

        expect(AppealsApi::StatsReportMailer).not_to receive(:build)

        described_class.new.perform
      end

      it 'is disabled when emails are not configured to send' do
        Flipper.enable(:decision_review_monthly_stats_report_enabled)
        allow(FeatureFlipper).to receive(:send_email?).and_return(false)

        expect(AppealsApi::StatsReportMailer).not_to receive(:build)

        described_class.new.perform
      end
    end
  end
end
