# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/failure_notification'
require 'va_notify/service'

RSpec.describe Lighthouse::FailureNotification, type: :job do
  subject { described_class }

  let(:notify_client_stub) { instance_double(VaNotify::Service) }
  let(:user_account) { create(:user_account) }
  let(:document_type) { 'L029' }
  let(:document_description) { 'Copy of a DD214' }
  let(:filename) { 'docXXXX-XXte.pdf' }
  let(:icn) { user_account.icn }
  let(:first_name) { 'Bob' }
  let(:issue_instant) { Time.now.to_i }
  let(:formatted_submit_date) do
    # We want to return all times in EDT
    timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

    # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
    timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end
  let(:date_submitted) { formatted_submit_date }
  let(:date_failed) { formatted_submit_date }

  before do
    allow(Rails.logger).to receive(:info)
  end

  context 'when Lighthouse::FailureNotification is called' do
    it 'enqueues a failure notification mailer to send to the veteran' do
      allow(VaNotify::Service).to receive(:new) { notify_client_stub }

      subject.perform_async(icn, first_name, filename, date_submitted, date_failed) do
        expect(notify_client_stub).to receive(:send_email).with(
          {
            recipient_identifier: { id_value: user_account.icn, id_type: 'ICN' },
            template_id: 'fake_template_id',
            personalisation: {
              first_name:,
              document_type: document_description,
              filename: file_name,
              date_submitted: formatted_submit_date,
              date_failed: formatted_submit_date
            }
          }
        )

        expect(Rails.logger)
          .to receive(:info)
          .with('Lighthouse::FailureNotification email sent')
      end
    end
  end

  context 'when retries are exhausted' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(StatsD).to receive(:increment)
    end

    let(:message) { 'Lighthouse::FailureNotification email could not be sent' }
    let(:statsd_tags) { ['service:claim-status', "function: #{message}"] }

    it 'logs failure and increments silent_failure metric' do
      expect(Rails.logger)
        .to receive(:info)
        .with(message)
      Lighthouse::FailureNotification.within_sidekiq_retries_exhausted_block do
        expect(StatsD).to receive(:increment).with('silent_failure', tags: statsd_tags)
      end
    end
  end
end
