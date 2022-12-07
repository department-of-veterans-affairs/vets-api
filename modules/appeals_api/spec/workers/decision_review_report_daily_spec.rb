# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::DecisionReviewReportDaily, type: :job do
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
      with_settings(Settings.modules_appeals_api.reports.daily_decision_review, enabled: true) do
        Timecop.freeze
        date_to = Time.zone.now
        date_from = date_to.monday? ? 3.days.ago : 1.day.ago

        expect(AppealsApi::DecisionReviewMailer).to receive(:build).once.with(
          date_from: date_from.beginning_of_day,
          date_to: date_to,
          friendly_duration: 'Daily',
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
