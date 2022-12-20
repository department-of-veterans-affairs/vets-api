# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::DailyErrorReport, type: :job do
  describe '#perform' do
    it 'sends mail' do
      recipients = %w[
        drew.fisher@adhocteam.us
        jack.schuss@oddball.io
        kelly@adhocteam.us
        laura.trager@adhocteam.us
        nathan.wright@oddball.io
      ]
      with_settings(Settings.modules_appeals_api.reports.daily_error, enabled: true) do
        allow(YAML).to receive(:load_file).and_return({ 'common' => recipients })
        expect(AppealsApi::DailyErrorReportMailer).to receive(:build).once.with(
          recipients: recipients
        ).and_return(double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).once
        end)

        described_class.new.perform
      end
    end

    it 'does not send email when no recipients are received' do
      messager_instance = instance_double('AppealsApi::Slack::Messager')
      with_settings(Settings.modules_appeals_api.reports.daily_error, enabled: true) do
        allow(YAML).to receive(:load_file).and_return({})
        allow(AppealsApi::Slack::Messager).to receive(:new).and_return(messager_instance)
        expect(messager_instance).to receive(:notify!)
        expect(AppealsApi::DecisionReviewMailer).not_to receive(:build)

        described_class.new.perform
      end
    end
  end
end
