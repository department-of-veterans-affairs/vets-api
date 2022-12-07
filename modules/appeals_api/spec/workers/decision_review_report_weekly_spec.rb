# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::DecisionReviewReportWeekly, type: :job do
  describe '#perform' do
    recipients = %w[
      drew.fisher@adhocteam.us
      jack.schuss@oddball.io
      kelly@adhocteam.us
      laura.trager@adhocteam.us
      nathan.wright@oddball.io
    ]

    before do
      stub_const("#{described_class}::RECIPIENTS", recipients)
    end

    it 'sends mail' do
      with_settings(Settings.modules_appeals_api.reports.weekly_decision_review, enabled: true) do
        Timecop.freeze
        date_to = Time.zone.now
        date_from = 1.week.ago.beginning_of_day

        expect(AppealsApi::DecisionReviewMailer).to receive(:build).once.with(
          date_from: date_from,
          date_to: date_to,
          friendly_duration: 'Weekly',
          recipients: recipients
        ).and_return(double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).once
        end)

        described_class.new.perform

        Timecop.return
      end
    end
  end
end
