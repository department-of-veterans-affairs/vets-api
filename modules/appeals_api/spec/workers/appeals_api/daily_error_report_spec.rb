# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::DailyErrorReport, type: :job do
  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.modules_appeals_api.reports.daily_error, enabled: true) do
        expect(AppealsApi::DailyErrorReportMailer).to receive(:build)
          .once
          .and_return(double.tap do |mailer|
            expect(mailer).to receive(:deliver_now).once
          end)

        described_class.new.perform
      end
    end
  end
end
