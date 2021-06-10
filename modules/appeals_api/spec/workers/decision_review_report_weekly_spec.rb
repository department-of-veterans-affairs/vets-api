# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::DecisionReviewReportWeekly, type: :job do
  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.modules_appeals_api.reports.decision_review, enabled: true) do
        Timecop.freeze
        date_to = Time.zone.now
        date_from = 1.week.ago.beginning_of_day

        expect(AppealsApi::DecisionReviewMailer).to receive(:build).once.with(
          date_from: date_from,
          date_to: date_to,
          friendly_duration: 'Weekly'
        ).and_return(double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).once
        end)

        described_class.new.perform

        Timecop.return
      end
    end
  end
end
