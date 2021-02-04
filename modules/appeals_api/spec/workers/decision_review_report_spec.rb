# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::DecisionReviewReportDaily, type: :job do
  describe '#perform' do
    it 'sends mail' do
      with_settings(Settings.modules_appeals_api, report_enabled: true) do
        Timecop.freeze
        date_to = Time.zone.now
        date_from = date_to.monday? ? 3.days.ago : 1.day.ago

        expect(AppealsApi::DecisionReviewMailer).to receive(:build).once.with(
          date_from: date_from,
          date_to: date_to,
          friendly_duration: 'Daily'
        ).and_return(double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).once
        end)

        described_class.new.perform

        Timecop.return
      end
    end
  end
end
