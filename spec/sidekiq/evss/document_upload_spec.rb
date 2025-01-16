# frozen_string_literal: true

require 'rails_helper'

require 'evss/document_upload'
require 'va_notify/service'

RSpec.describe EVSS::DocumentUpload, type: :job do
  subject { described_class }

  let(:client_stub) { instance_double(EVSS::DocumentsService) }
  let(:notify_client_stub) { instance_double(VaNotify::Service) }
  let(:uploader_stub) { instance_double(EVSSClaimDocumentUploader) }

  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:user) { create(:user, :loa3) }
  let(:filename) { 'doctors-note.pdf' }
  let(:document_data) do
    EVSSClaimDocument.new(
      evss_claim_id: 189_625,
      file_name: filename,
      tracked_item_id: 33,
      document_type: 'L023'
    )
  end
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

  let(:issue_instant) { Time.now.to_i }
  let(:args) do
    {
      'args' => [{ 'va_eauth_firstName' => 'Bob' }, user_account_uuid, { 'file_name' => filename }],
      'created_at' => issue_instant,
      'failed_at' => issue_instant
    }
  end
  let(:tags) { subject::DD_ZSF_TAGS }

  before do
    allow(Rails.logger).to receive(:info)
    allow(StatsD).to receive(:increment)
  end

  it 'retrieves the file and uploads to EVSS' do
    allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
    allow(EVSS::DocumentsService).to receive(:new) { client_stub }
    file = File.read("#{::Rails.root}/spec/fixtures/files/#{filename}")
    allow(uploader_stub).to receive(:retrieve_from_store!).with(filename) { file }
    allow(uploader_stub).to receive(:read_for_upload) { file }
    expect(uploader_stub).to receive(:remove!).once
    expect(client_stub).to receive(:upload).with(file, document_data)
    described_class.new.perform(auth_headers, user.uuid, document_data.to_serializable_hash)
  end

  context 'when cst_send_evidence_failure_emails is enabled' do
    before do
      Flipper.enable(:cst_send_evidence_failure_emails)
    end

    let(:formatted_submit_date) do
      # We want to return all times in EDT
      timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

      # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
      timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
    end

    it 'calls EVSS::FailureNotification' do
      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(EVSS::FailureNotification).to receive(:perform_async).with(
          user_account.icn,
          'Bob', # first_name
          'docXXXX-XXte.pdf', # filename
          formatted_submit_date, # date_submitted
          formatted_submit_date # date_failed
        )

        expect(Rails.logger)
          .to receive(:info)
          .with('EVSS::DocumentUpload exhaustion handler email queued')
        expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation', tags:)
      end
    end
  end

  context 'when cst_send_evidence_failure_emails is disabled' do
    before do
      Flipper.disable(:cst_send_evidence_failure_emails)
    end

    it 'does not call Lighthouse::Failure Notification' do
      subject.within_sidekiq_retries_exhausted_block(args) do
        expect(EVSS::FailureNotification).not_to receive(:perform_async)
      end
    end
  end
end
