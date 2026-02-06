# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::DailyErrorReport, type: :job do
  it_behaves_like 'a monitored worker'

  describe '#perform' do
    let(:recipients) do
      %w[drew.fisher@adhocteam.us
         jack.schuss@oddball.io
         kelly@adhocteam.us
         laura.trager@adhocteam.us
         nathan.wright@oddball.io]
    end

    before { Flipper.enable :decision_review_daily_error_report_enabled } # rubocop:disable Project/ForbidFlipperToggleInSpecs

    it 'sends mail' do
      allow(YAML).to receive(:load_file).and_return({ 'common' => recipients })
      expect(AppealsApi::DailyErrorReportMailer).to receive(:build).once.with(
        recipients:
      ).and_return(double.tap do |mailer|
        expect(mailer).to receive(:deliver_now).once
      end)

      described_class.new.perform
    end

    it 'does not send email if flipper setting is disabled' do
      Flipper.disable :decision_review_daily_error_report_enabled # rubocop:disable Project/ForbidFlipperToggleInSpecs
      allow(YAML).to receive(:load_file).and_return({ 'common' => recipients })
      expect(AppealsApi::DailyErrorReportMailer).not_to receive(:build)
      described_class.new.perform
    end

    it 'notifies slack when there are no recipients' do
      messager_instance = instance_double(AppealsApi::Slack::Messager)

      allow(YAML).to receive(:load_file).and_return({})
      allow(AppealsApi::Slack::Messager).to receive(:new).and_return(messager_instance)
      expect(messager_instance).to receive(:notify!)
      expect(AppealsApi::DecisionReviewMailer).not_to receive(:build)

      described_class.new.perform
    end
  end
end
