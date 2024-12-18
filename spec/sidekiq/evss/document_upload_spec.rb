# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require 'evss/document_upload'
require 'va_notify/service'

RSpec.describe EVSS::DocumentUpload, type: :job do
  subject(:job) do
    described_class.perform_async(auth_headers, user.uuid, document_data.to_serializable_hash)
  end
  # subject { described_class }

  let(:client_stub) { instance_double('EVSS::DocumentsService') }
  let(:job_id) { job }
  let(:job_class) { 'EVSS::DocumentUpload' }
  let(:claim_id) { '4567' }
  let(:tracked_item_id) { '1234' }
  let(:document_type) { 'L023' }

  let(:formatted_submit_date) do
    # We want to return all times in EDT
    timestamp = Time.at(issue_instant).in_time_zone('America/New_York')

    # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
    timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
  end
  let(:created_at) { DateTime.new(2023, 4, 2) }

  let(:notify_client_stub) { instance_double(VaNotify::Service) }
  let(:uploader_stub) { instance_double('EVSSClaimDocumentUploader') }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:filename) { 'doctors-note.pdf' }
  let(:document_data) do
    EVSSClaimDocument.new(
      evss_claim_id: claim_id,
      file_name: filename,
      tracked_item_id:,
      document_type:
    )
  end
  let(:personalisation) do
    { first_name: user.first_name,
      filename:,
      date_submitted: created_at.strftime('%B %d, %Y'),
      date_failed: created_at.strftime('%B %d, %Y') }
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

  before do
    allow(Rails.logger).to receive(:info)
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

  it 'creates a failed evidence submission record' do
    subject.within_sidekiq_retries_exhausted_block(args) do
      byebug
      expect(EvidenceSubmission.va_notify_email_not_sent.length).to equal(1)
      # expect do
      #   post :create,
      #        params: { job_id:,
      #                  job_class:,
      #                  claim_id:,
      #                  tracked_item_id:,
      #                  upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
      #                  user_account:,
      #                  template_metadata_ciphertext: { personalisation: }.to_json }
      # end.to change(EvidenceSubmission.va_notify_email_not_sent, :count).by(1)
    end
  end
end
