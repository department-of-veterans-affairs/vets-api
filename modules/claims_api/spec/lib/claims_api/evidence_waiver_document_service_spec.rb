# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::EvidenceWaiverDocumentService do
  subject { described_class.new }

  let(:claim) do
    create(:auto_established_claim,
           evss_id: 600_400_688,
           id: '581128c6-ad08-4b1e-8b82-c3640e829fb3')
  end
  let(:evidence) do
    create(:evidence_waiver_submission, :with_full_headers, claim_id: claim.id,
                                                            id: '43fc03ab-86df-4386-977b-4e5b87f0817f',
                                                            tracked_items: [234, 235])
  end
  let(:pdf_path) { '/path/to/nonexistent/document.pdf' }
  let(:doc_type) { 'evidence_waiver' }
  let(:ptcpnt_vet_id) { 'VET456' }

  describe '#create_upload' do
    context 'when PDF file does not exist' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(pdf_path).and_return(false)
      end

      it 'raises Errno::ENOENT with appropriate error message' do
        expect do
          subject.create_upload(
            claim: evidence,
            pdf_path:,
            doc_type:,
            ptcpnt_vet_id:
          )
        end.to raise_error(Errno::ENOENT, /Evidence waiver PDF document not found/)
      end

      it 'includes claim details in error message' do
        expect do
          subject.create_upload(
            claim: evidence,
            pdf_path:,
            doc_type:,
            ptcpnt_vet_id:
          )
        end.to raise_error(Errno::ENOENT, /ews_id: #{evidence.id}.*claim_id: #{evidence.claim_id}/)
      end

      it 'logs the initial file not found error' do
        allow(ClaimsApi::Logger).to receive(:log)
        expect(ClaimsApi::Logger).to receive(:log).with(
          'Ews_Document_service',
          detail: include('Evidence waiver PDF document not found')
        ).at_least(:once)

        expect do
          subject.create_upload(
            claim: evidence,
            pdf_path:,
            doc_type:,
            ptcpnt_vet_id:
          )
        end.to raise_error(Errno::ENOENT)
      end

      it 'does not attempt to generate body or upload' do
        expect_any_instance_of(described_class).not_to receive(:generate_body)
        expect_any_instance_of(described_class).not_to receive(:generate_upload_body)
        expect_any_instance_of(ClaimsApi::BD).not_to receive(:upload_document)

        expect do
          subject.create_upload(
            claim: evidence,
            pdf_path:,
            doc_type:,
            ptcpnt_vet_id:
          )
        end.to raise_error(Errno::ENOENT)
      end
    end
  end
end
