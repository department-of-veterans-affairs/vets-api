# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::DecisionReviewReportWeekly, type: :job do
  it_behaves_like 'a monitored worker'

  describe '#perform' do
    it 'sends mail' do
      recipients = %w[
        drew.fisher@adhocteam.us
        jack.schuss@oddball.io
        kelly@adhocteam.us
        nathan.wright@oddball.io
      ]
      with_settings(Settings.modules_appeals_api.reports.weekly_decision_review, enabled: true) do
        Timecop.freeze
        date_to = Time.zone.now
        date_from = 1.week.ago.beginning_of_day
        allow(YAML).to receive(:load_file).and_return({ 'common' => recipients,
                                                        'production' => ['laura.trager@adhocteam.us'] })
        expect(AppealsApi::DecisionReviewMailer).to receive(:build).once.with(
          date_from:,
          date_to:,
          friendly_duration: 'Weekly',
          recipients:
        ).and_return(double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).once
        end)

        described_class.new.perform

        Timecop.return
      end
    end

    it 'does not send email when no recipients are received' do
      messager_instance = instance_double('AppealsApi::Slack::Messager')
      with_settings(Settings.modules_appeals_api.reports.weekly_decision_review, enabled: true) do
        allow(YAML).to receive(:load_file).and_return({})
        allow(AppealsApi::Slack::Messager).to receive(:new).and_return(messager_instance)
        expect(messager_instance).to receive(:notify!)
        expect(AppealsApi::DecisionReviewMailer).not_to receive(:build)

        described_class.new.perform
      end
    end
  end
end
