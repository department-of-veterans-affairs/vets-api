# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ClaimAuditor, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  it 'submits successfully' do
    expect do
      subject.perform_async
    end.to change(subject.jobs, :size).by(1)
  end

  it 'notifies slack' do
    create(:auto_established_claim, :status_errored)
    expect_any_instance_of(SlackNotify::Client).to receive(:notify)

    with_settings(Settings.claims_api,
                  audit_enabled: true,
                  slack: OpenStruct.new(webhook_url: 'https://example.com'),
                  claims_error_reporting: OpenStruct.new(environment_name: 'test')) do
      subject.new.perform
    end
  end

  it 'does not notify slack' do
    create(:auto_established_claim, status: ClaimsApi::AutoEstablishedClaim::PENDING)
    expect_any_instance_of(SlackNotify::Client).not_to receive(:notify)

    with_settings(Settings.claims_api,
                  audit_enabled: true,
                  slack: OpenStruct.new(webhook_url: 'https://example.com'),
                  claims_error_reporting: OpenStruct.new(environment_name: 'test')) do
      subject.new.perform
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Claim Auditor Job'
      msg = { 'class' => described_class,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: nil,
          detail: "Job retries exhausted for #{described_class}",
          error: error_msg
        )
      end
    end
  end
end
