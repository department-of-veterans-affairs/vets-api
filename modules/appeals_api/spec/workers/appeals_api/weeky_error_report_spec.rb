# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::WeeklyErrorReport, type: :job do
  describe '#perform' do
    it 'sends mail' do
      Flipper.enable(:decision_review_weekly_error_report_enabled)
      expect(AppealsApi::WeeklyErrorReportMailer).to receive(:build)
        .once
        .and_return(double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).once
        end)

      described_class.new.perform
    end

    it 'does not send report email if flipper disabled' do
      Flipper.disable(:decision_review_weekly_error_report_enabled)
      expect(AppealsApi::WeeklyErrorReportMailer).not_to receive(:build)

      described_class.new.perform
    end
  end
end
