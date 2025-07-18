# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/uploader'

RSpec.describe ClaimsEvidenceApi::Uploader do
  let(:claim) { build(:fake_saved_claim, :with_attachments, id: 23) }
  let(:pa) { build(:claim_evidence) }
  let(:submission) { build(:claims_evidence_submission) }
  let(:attempt) { build(:claims_evidence_submission_attempt) }

  let(:service) { ClaimsEvidenceApi::Service::Files.new }
  let(:stamper) { PDFUtilities::PDFStamper.new([]) }
  let(:pdf_path) { 'path/to/pdf.pdf' }
  let(:content_source) { __FILE__ }

  let(:uploader) { ClaimsEvidenceApi::Uploader.new('VETERAN:SSN:123456789', content_source:) }
  # stamping is stubbed, but will raise an error if the provided stamp_set is invalid
  let(:claim_stamp_set) { [anything] }
  let(:attachment_stamp_set) { [anything] }

  before do
    allow(ClaimsEvidenceApi::Service::Files).to receive(:new).and_return service

    allow(PDFUtilities::PDFStamper).to receive(:new).and_return stamper
    allow(stamper).to receive(:run).and_return pdf_path

    allow(SavedClaim).to receive(:find).with(claim.id).and_return claim
    allow(claim).to receive(:to_pdf).and_return pdf_path

    allow(PersistentAttachment).to receive(:find_by).with(id: pa.id, saved_claim_id: claim.id).and_return pa
    allow(pa).to receive(:to_pdf).and_return pdf_path
  end

  context 'with generating the pdf and stamping' do
    it 'creates tracking entries on successful upload' do
      expect(uploader).to receive(:upload_attachment_pdf).twice

      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(saved_claim: claim, persistent_attachment_id: nil, form_id: claim.form_id).and_return submission
      expect(submission.submission_attempts).to receive(:create).and_return attempt

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: claim.created_at,
        documentTypeId: claim.document_type
      }
      response = build(:claims_evidence_service_files_response, :success)
      expect(service).to receive(:upload).with(pdf_path, provider_data:).and_return response

      uploader.upload_saved_claim_evidence(claim.id, claim_stamp_set, attachment_stamp_set)

      expect(submission.file_uuid).to eq response.body['uuid']
      expect(attempt.status).to eq 'accepted'
      expect(attempt.metadata).to eq JSON.parse(provider_data.to_json)
      expect(attempt.response).to eq response.body
    end
  end

  context 'with pdf_path provided and no stamp set' do
    it 'successfully uploads an attachment' do
      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(saved_claim: claim, persistent_attachment_id: pa.id, form_id: claim.form_id).and_return submission
      expect(submission.submission_attempts).to receive(:create).and_return attempt

      expect(pa).not_to receive(:to_pdf)
      expect(PDFUtilities::PDFStamper).not_to receive(:new)

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: pa.created_at,
        documentTypeId: pa.document_type
      }
      response = build(:claims_evidence_service_files_response, :success)
      expect(service).to receive(:upload).with(pdf_path, provider_data:).and_return response

      uploader.upload_attachment_pdf(claim.id, pa.id, pdf_path)

      expect(submission.file_uuid).to eq response.body['uuid']
      expect(attempt.status).to eq 'accepted'
      expect(attempt.metadata).to eq JSON.parse(provider_data.to_json)
      expect(attempt.response).to eq response.body
    end
  end

  context 'with unsuccessful upload' do
    it 'raises an exception on unauthorized' do
      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(saved_claim: claim, persistent_attachment_id: nil, form_id: claim.form_id).and_return submission
      expect(submission.submission_attempts).to receive(:create).and_return attempt

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: claim.created_at,
        documentTypeId: claim.document_type
      }
      response = build(:claims_evidence_service_files_response, :unauthorized)
      expect(service).to receive(:upload).with(pdf_path, provider_data:).and_return response

      error_key = response.body.dig('messages', 0, 'key')
      error_msg = response.body.dig('messages', 0, 'text')
      expect { uploader.upload_saved_claim_pdf(claim.id, pdf_path) }.to raise_error ClaimsEvidenceApi::Exceptions::VefsError, "#{error_key} - #{error_msg}"

      expect(submission.file_uuid).to be nil
      expect(attempt.status).to eq 'failure'
      expect(attempt.metadata).to eq JSON.parse(provider_data.to_json)
      expect(attempt.error_message).to eq response.body
    end

    it 'raises an exception on endpoint error' do
      expect(ClaimsEvidenceApi::Submission).to receive(:find_or_create_by).with(saved_claim: claim, persistent_attachment_id: nil, form_id: claim.form_id).and_return submission
      expect(submission.submission_attempts).to receive(:create).and_return attempt

      provider_data = {
        contentSource: content_source,
        dateVaReceivedDocument: claim.created_at,
        documentTypeId: claim.document_type
      }
      response = build(:claims_evidence_service_files_response, :error)
      expect(service).to receive(:upload).with(pdf_path, provider_data:).and_return response

      error_key = response.body['code']
      error_msg = response.body['message']
      expect { uploader.upload_saved_claim_pdf(claim.id, pdf_path) }.to raise_error ClaimsEvidenceApi::Exceptions::VefsError, "#{error_key} - #{error_msg}"

      expect(submission.file_uuid).to be nil
      expect(attempt.status).to eq 'failure'
      expect(attempt.metadata).to eq JSON.parse(provider_data.to_json)
      expect(attempt.error_message).to eq response.body
    end
  end

  context 'with invalid folder_identifier' do
    it 'raises an error on initialization' do
      expect { ClaimsEvidenceApi::Uploader.new('INVALID') }.to raise_error ClaimsEvidenceApi::XFolderUri::InvalidFolderType
    end

    it 'raises an error attempting to update the identifier' do
      expect { uploader.folder_identifier = 'INVALID' }.to raise_error ClaimsEvidenceApi::XFolderUri::InvalidFolderType
    end
  end
end
