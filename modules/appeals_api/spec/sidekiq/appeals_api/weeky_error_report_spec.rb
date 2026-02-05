# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::WeeklyErrorReport, type: :job do
  it_behaves_like 'a monitored worker'

  describe '#perform' do
    it 'sends mail' do
      Flipper.enable(:decision_review_weekly_error_report_enabled) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      expect(AppealsApi::WeeklyErrorReportMailer).to receive(:build)
        .once
        .and_return(double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).once
        end)

      described_class.new.perform
    end

    it 'does not send report email if flipper disabled' do
      Flipper.disable(:decision_review_weekly_error_report_enabled) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      expect(AppealsApi::WeeklyErrorReportMailer).not_to receive(:build)

      described_class.new.perform
    end
  end
end
