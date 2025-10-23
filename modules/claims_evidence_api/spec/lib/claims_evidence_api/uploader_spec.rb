# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/uploader'

RSpec.describe ClaimsEvidenceApi::Uploader do
  let(:created_at) { Time.current }
  let(:claim) { build(:fake_saved_claim, id: 23, created_at:) }
  let(:pa) { build(:claim_evidence, id: 42, created_at:) }
  let(:submission) { build(:claims_evidence_submission) }
  let(:attempt) { build(:claims_evidence_submission_attempt) }
  let(:monitor) { ClaimsEvidenceApi::Monitor::Uploader.new }
  let(:service) { ClaimsEvidenceApi::Service::Files.new }
  let(:stamper) { PDFUtilities::PDFStamper.new([]) }
  let(:pdf_path) { 'path/to/pdf.pdf' }
  let(:content_source) { 'VA.gov' }
  let(:va_received_at) { DateTime.parse(claim.created_at.to_s).in_time_zone(ClaimsEvidenceApi::TIMEZONE).strftime('%Y-%m-%d') }
  let(:folder_identifier) { 'VETERAN:SSN:123456789' }
  let(:uploader) { ClaimsEvidenceApi::Uploader.new(folder_identifier) }
  # stamping is stubbed, but will raise an error if the provided stamp_set is invalid
  let(:claim_stamp_set) { [anything] }
  let(:attachment_stamp_set) { [anything] }

  around do |example|
    Timecop.freeze(Time.now.utc) do
      example.run
    end
  end

  before do
    allow(ClaimsEvidenceApi::Monitor::Uploader).to receive(:new).and_return monitor
    allow(ClaimsEvidenceApi::Service::Files).to receive(:new).and_return service

    allow(PDFUtilities::PDFStamper).to receive(:new).and_return stamper
    allow(stamper).to receive(:run).and_return pdf_path

    allow(SavedClaim).to receive(:find).with(claim.id).and_return claim
    allow(claim).to receive(:to_pdf).and_return pdf_path

    allow(PersistentAttachment).to receive(:find_by).with(id: pa.id, saved_claim_id: claim.id).and_return pa
    allow(pa).to receive(:to_pdf).and_return pdf_path
  end

  describe '#format_datetime' do
    it 'converts UTC to expected date' do
      future_utc = 'Tue, 23 Sep 2025 00:44:24.175627000 +0000'
      expected = '2025-09-22'
      expect(expected).to eq uploader.send(:format_datetime, future_utc)
    end

    it 'returns the same day' do
      same_day = 'Tue, 23 Sep 2025 00:44:24.175627000 -0400'
      expected = '2025-09-23'
      expect(expected).to eq uploader.send(:format_datetime, same_day)
    end
  end

  context 'with generating the pdf and stamping' do
    it 'creates tracking entries on successful upload' do
      args = { saved_claim_id: claim.id, persistent_attachment_id: nil, form_id: claim.form_id }
      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(**args).and_return submission
      expect(submission.submission_attempts).to receive(:create).and_return attempt

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: va_received_at,
        documentTypeId: claim.document_type
      }
      response = build(:claims_evidence_service_files_response, :success)
      expect(service).to receive(:upload).with(pdf_path, provider_data:).and_return response

      expect(monitor).to receive(:track_upload_begun)
      expect(monitor).to receive(:track_upload_attempt)
      expect(monitor).to receive(:track_upload_success)

      uploader.upload_saved_claim_evidence(claim.id, claim_stamp_set, attachment_stamp_set)

      expect(submission.file_uuid).to eq response.body['uuid']
      expect(attempt.status).to eq 'accepted'
      expect(attempt.metadata).to eq JSON.parse(provider_data.to_json)
      expect(attempt.response).to eq response.body
    end
  end

  context 'with pdf_path provided and no stamp set' do
    it 'successfully uploads an attachment' do
      args = { saved_claim_id: claim.id, persistent_attachment_id: pa.id, form_id: claim.form_id }
      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(**args).and_return submission
      expect(submission.submission_attempts).to receive(:create).and_return attempt

      expect(pa).not_to receive(:to_pdf)
      expect(PDFUtilities::PDFStamper).not_to receive(:new)

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: va_received_at,
        documentTypeId: pa.document_type
      }
      response = build(:claims_evidence_service_files_response, :success)
      expect(service).to receive(:upload).with(pdf_path, provider_data:).and_return response

      expect(monitor).to receive(:track_upload_begun)
      expect(monitor).to receive(:track_upload_attempt)
      expect(monitor).to receive(:track_upload_success)

      uploader.upload_evidence(claim.id, pa.id, file_path: pdf_path)

      expect(submission.file_uuid).to eq response.body['uuid']
      expect(attempt.status).to eq 'accepted'
      expect(attempt.metadata).to eq JSON.parse(provider_data.to_json)
      expect(attempt.response).to eq response.body
    end
  end

  context 'with unsuccessful upload' do
    it 'raises an exception' do
      args = { saved_claim_id: claim.id, persistent_attachment_id: pa.id, form_id: claim.form_id }
      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(**args).and_return submission
      expect(submission.submission_attempts).to receive(:create).and_return attempt

      expect(pa).not_to receive(:to_pdf)
      expect(PDFUtilities::PDFStamper).not_to receive(:new)

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: va_received_at,
        documentTypeId: claim.document_type
      }
      error = build(:claims_evidence_service_files_error, :error)
      expect(service).to receive(:upload).with(pdf_path, provider_data:).and_raise error

      expect(monitor).to receive(:track_upload_begun)
      expect(monitor).to receive(:track_upload_attempt)
      expect(monitor).to receive(:track_upload_failure)

      expect { uploader.upload_evidence(claim.id, pa.id, file_path: pdf_path) }.to raise_error error

      expect(error.message).to eq 'VEFSERR40009'
      expect(submission.file_uuid).to be_nil
      expect(attempt.status).to eq 'failed'
      expect(attempt.metadata).to eq JSON.parse(provider_data.to_json)
      expect(attempt.error_message).to eq error.body
    end
  end

  context 'with invalid folder_identifier' do
    it 'raises an error on initialization' do
      expect { ClaimsEvidenceApi::Uploader.new('INVALID') }.to raise_error ClaimsEvidenceApi::FolderIdentifier::InvalidFolderType
    end

    it 'raises an error attempting to update the identifier' do
      expect { uploader.folder_identifier = 'INVALID' }.to raise_error ClaimsEvidenceApi::FolderIdentifier::InvalidFolderType
    end
  end

  context 'claim with attachments' do # for coverage
    let(:claim) { build(:fake_saved_claim, :with_attachments, id: 23) }

    before do
      uploader.instance_variable_set(:@submission, submission)
    end

    it 'calls upload evidence for each attachment' do
      expect(uploader).to receive(:upload_evidence).with(claim.id, stamp_set: nil)
      expect(uploader).to receive(:upload_evidence).with(claim.id, claim.persistent_attachments[0].id, stamp_set: nil)
      expect(uploader).to receive(:upload_evidence).with(claim.id, claim.persistent_attachments[1].id, stamp_set: nil)

      uploader.upload_saved_claim_evidence(claim.id)
    end
  end
end
