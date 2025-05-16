# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/service'
require 'lighthouse_document'
require 'lighthouse/benefits_documents/configuration'

RSpec.describe BenefitsDocuments::Service do
  subject { service }

  let(:user) { create(:user, :loa3) }
  let(:user_account) { create(:user_account) }
  let(:service) { BenefitsDocuments::Service.new(user) }

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
    user.user_account_uuid = user_account.id
    user.save!
  end

  describe '#queue_document_upload' do
    describe 'when uploading single file' do
      let(:upload_file) do
        f = Tempfile.new(['file with spaces', '.txt'])
        f.write('test')
        f.rewind
        rack_file = Rack::Test::UploadedFile.new(f.path, 'image/jpeg')

        ActionDispatch::Http::UploadedFile.new(
          tempfile: rack_file.tempfile,
          filename: rack_file.original_filename,
          type: rack_file.content_type
        )
      end

      let(:params) do
        {
          file_number: 'xyz',
          claimId: '1',
          file: upload_file,
          trackedItemIds: ['1'], # Lighthouse expects an array for tracked items
          documentType: 'L023',
          password: nil
        }
      end

      let(:issue_instant) { Time.current.to_i }
      let(:submitted_date) do
        BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
      end

      context 'when cst_synchronous_evidence_uploads is false and cst_send_evidence_submission_failure_emails is true' do # rubocop:disable Layout/LineLength
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:cst_synchronous_evidence_uploads,
                                                    instance_of(User)).and_return(false)
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:info)
        end

        it 'enqueues a job' do
          expect do
            service.queue_document_upload(params)
          end.to change(Lighthouse::EvidenceSubmissions::DocumentUpload.jobs, :size).by(1)
        end

        it 'records evidence submission with CREATED status' do
          subject.queue_document_upload(params)
          expect(EvidenceSubmission.count).to eq(1)
          evidence_submission = EvidenceSubmission.first
          current_personalisation = JSON.parse(evidence_submission.template_metadata)['personalisation']
          expect(evidence_submission.upload_status)
            .to eql(BenefitsDocuments::Constants::UPLOAD_STATUS[:CREATED])
          expect(current_personalisation['date_submitted']).to eql(submitted_date)
          expect(evidence_submission.tracked_item_id).to be(1)
          expect(StatsD)
            .to have_received(:increment)
            .with('cst.lighthouse.document_uploads.evidence_submission_record_created')
          expect(Rails.logger)
            .to have_received(:info)
            .with('LH - Created Evidence Submission Record', any_args)
        end
      end

      context 'when cst_synchronous_evidence_uploads and cst_send_evidence_submission_failure_emails is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:cst_synchronous_evidence_uploads,
                                                    instance_of(User)).and_return(false)
        end

        it 'does not record an evidence submission' do
          expect do
            service.queue_document_upload(params)
          end.not_to change(EvidenceSubmission, :count)
        end
      end

      context 'when cst_synchronous_evidence_uploads is true and cst_send_evidence_submission_failure_emails is false' do # rubocop:disable Layout/LineLength
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:cst_synchronous_evidence_uploads,
                                                    instance_of(User)).and_return(true)
        end

        it 'does not enqueue a job' do
          VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_200_pdf') do
            expect do
              service.queue_document_upload(params)
            end.not_to change(Lighthouse::EvidenceSubmissions::DocumentUpload.jobs, :size)
            expect(EvidenceSubmission.count).to eq(0)
          end
        end
      end
    end
  end

  context 'claim letters' do
    describe '#claim_letters_search' do
      it 'receives a list of claim letters' do
        response_body = {
          data: {
            documents: [
              {
                docTypeId: 184,
                subject: 'string',
                documentUuid: '12345678-ABCD-0123-cdef-124345679ABC',
                originalFileName: 'SupportingDocument.pdf',
                documentTypeLabel: 'VA 21-526 Veterans Application for Compensation or Pension',
                trackedItemId: 600_000_001,
                uploadedDateTime: '2016-02-04T17:51:56Z'
              }
            ]
          }
        }

        allow_any_instance_of(Faraday::Connection).to receive(:post)
          .and_return(Faraday::Response.new(
                        status: 200, body: response_body
                      ))
        expect_any_instance_of(BenefitsDocuments::Configuration)
          .to(receive(:claim_letters_search).once.and_call_original)

        response = subject.claim_letters_search(file_number: user.ssn)

        expect(response.body.as_json['data']['documents'][0]['docTypeId']).to eq(184)
      end
    end

    describe '#claim_letter_download' do
      it 'receives content of a claim letter pdf' do
        response_body = 'claim letter pdf file content'

        allow_any_instance_of(Faraday::Connection).to receive(:post)
          .and_return(Faraday::Response.new(
                        status: 200, body: response_body
                      ))
        expect_any_instance_of(BenefitsDocuments::Configuration)
          .to(receive(:claim_letter_download).once.and_call_original)

        response = subject.claim_letter_download(document_uuid: 'a-required-uuid', file_number: user.ssn)

        expect(response.body).to eq(response_body)
      end
    end
  end
end
