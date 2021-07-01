# frozen_string_literal: true

require 'rails_helper'
require 'support/form1010cg_helpers/build_claim_data_for'

RSpec.describe Form1010cg::DeliverAttachmentsJob do
  include Form1010cgHelpers

  it 'inherits Sidekiq::Worker' do
    expect(described_class.ancestors).to include(Sidekiq::Worker)
  end

  describe '#perform' do
    let(:vcr_options) do
      {
        aws: {
          record: :none,
          allow_unused_http_interactions: false,
          match_requests_on: %i[method host]
        },
        carma: {
          record: :none,
          allow_unused_http_interactions: false,
          match_requests_on: %i[method host uri]
        }
      }
    end

    describe 'unit' do
      let(:claim_guid) { SecureRandom.uuid }
      let(:pdf_file_path) { "tmp/pdfs/10-10CG_#{claim_guid}.pdf" }
      let(:poa_attachment_guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
      let(:poa_attachment_path) { "tmp/#{poa_attachment_guid}_doctors-note.jpg" }

      shared_examples 'a successful job with one document' do
        let(:claim) { build(:caregivers_assistance_claim, guid: claim_guid) }
        let(:submission) { build(:form1010cg_submission, claim_guid: claim_guid) }
        let(:carma_attachments) { double('carma_attachments') }
        let(:auditor) { double('auditor') }

        before do
          submission.claim = claim
          submission.save!
        end

        before do
          expect(Raven).to receive(:tags_context).with(claim_guid: claim_guid)
          expect(Form1010cg::Service).to receive(
            :collect_attachments
          ).with(claim).and_return([pdf_file_path, nil])
          expect(Form1010cg::Service).to receive(:submit_attachments!).with(
            submission.carma_case_id,
            claim.veteran_data['fullName'],
            pdf_file_path,
            nil
          ).and_return(carma_attachments)

          expect(carma_attachments).to receive(:to_hash).and_return(:ATTACHMENTS_HASH)

          expect(Form1010cg::Auditor).to receive(:new).with(Sidekiq.logger).and_return(auditor)
          expect(auditor).to receive(:record).with(
            :attachments_delivered,
            claim_guid: claim_guid,
            carma_case_id: submission.carma_case_id,
            attachments: :ATTACHMENTS_HASH
          )
        end

        after do
          expect { submission.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect { claim.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'processes the claim PDF' do
          subject.perform(claim_guid)
        end
      end

      shared_examples 'a successful job with two documents' do
        let(:form_data) { build_claim_data { |d| d['poaAttachmentId'] = poa_attachment_guid }.to_json }
        let(:claim) { build(:caregivers_assistance_claim, guid: claim_guid, form: form_data) }
        let(:submission) { build(:form1010cg_submission, claim_guid: claim_guid) }
        let(:attachment) { build(:form1010cg_attachment, guid: poa_attachment_guid) }
        let(:carma_attachments) { double('carma_attachments') }
        let(:auditor) { double('auditor') }

        before do
          # Cannot create an FormAttachment without having a file in store
          VCR.use_cassette("s3/object/put/#{poa_attachment_guid}/doctors-note.jpg", vcr_options[:aws]) do
            attachment.set_file_data!(
              Rack::Test::UploadedFile.new(
                Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg'),
                'image/jpg'
              )
            )
          end

          attachment.save!
          submission.claim = claim
          submission.save!
        end

        before do
          expect(Raven).to receive(:tags_context).with(claim_guid: claim_guid)
          expect(Form1010cg::Service).to receive(
            :collect_attachments
          ).with(claim).and_return([pdf_file_path, poa_attachment_path])
          expect(Form1010cg::Service).to receive(:submit_attachments!).with(
            submission.carma_case_id,
            claim.veteran_data['fullName'],
            pdf_file_path,
            poa_attachment_path
          ).and_return(carma_attachments)

          expect(carma_attachments).to receive(:to_hash).and_return(:ATTACHMENTS_HASH)

          expect(Form1010cg::Auditor).to receive(:new).with(Sidekiq.logger).and_return(auditor)
          expect(auditor).to receive(:record).with(
            :attachments_delivered,
            claim_guid: claim_guid,
            carma_case_id: submission.carma_case_id,
            attachments: :ATTACHMENTS_HASH
          )

          expect_any_instance_of(Form1010cg::Attachment).to receive(:get_file) do |remote_file|
            expect(remote_file).to receive(:delete)
            remote_file
          end
        end

        after do
          expect { submission.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect { claim.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect { attachment.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'processes the claim PDF and POA attachment' do
          subject.perform(claim_guid)
        end
      end

      it 'requires a claim_guid' do
        expect { subject.perform }.to raise_error(ArgumentError) do |error|
          expect(error.message).to eq('wrong number of arguments (given 0, expected 1)')
        end
      end

      context 'when submission is not found' do
        let(:claim_guid) { SecureRandom.uuid }
        let(:expected_exception_class) { ActiveRecord::RecordNotFound }

        it 'raises error' do
          expect { subject.perform(SecureRandom.uuid) }.to raise_error(expected_exception_class) do |error|
            expect(error.message).to include('Couldn\'t find Form1010cg::Submission')
          end
        end
      end

      context 'when claim is not found' do
        let(:claim_guid) { SecureRandom.uuid }
        let(:claim) { build(:caregivers_assistance_claim, guid: claim_guid) }
        let(:submission) { build(:form1010cg_submission, claim_guid: claim_guid) }

        let(:expected_exception_class) { described_class::MissingClaimException }

        before do
          submission.claim = claim
          submission.save!
          claim.delete # delete the claim but not the submission
        end

        after { submission.delete }

        it 'raises error' do
          expect { subject.perform(claim_guid) }.to raise_error(expected_exception_class) do |error|
            expect(error.message).to eq('Could not find a claim associated to this submission')
          end
        end
      end

      context 'when ::collect_attachments raises an error' do
        let(:claim_guid) { SecureRandom.uuid }
        let(:claim) { build(:caregivers_assistance_claim, guid: claim_guid) }
        let(:submission) { build(:form1010cg_submission, claim_guid: claim_guid) }

        let(:pdf_generation_exception) do
          class MyPdfGenerationError < StandardError; end
          MyPdfGenerationError.new('PDF could not be generated')
        end

        before do
          submission.claim = claim
          submission.save!
        end

        after do
          claim.delete
          submission.delete
        end

        it 'raises error' do
          expect(Form1010cg::Service).to receive(:collect_attachments).with(claim).and_raise(pdf_generation_exception)

          expect { subject.perform(claim_guid) }.to raise_error(pdf_generation_exception.class) do |error|
            expect(error.message).to eq(pdf_generation_exception.message)
          end
        end
      end

      it_behaves_like 'a successful job with one document'
      it_behaves_like 'a successful job with two documents'

      describe 'cleanup' do
        context 'when PDF file is still present' do
          before do
            expect(File).to receive(:exist?).with(pdf_file_path).and_return(true)
          end

          context 'and PDF deletion succeeds' do
            it_behaves_like 'a successful job with one document' do
              before do
                expect(File).to receive(:delete).with(pdf_file_path).and_return(true)
              end
            end
          end

          context 'and PDF deletion fails' do
            it_behaves_like 'a successful job with one document' do
              let(:pdf_delete_exception) do
                class MyPdfDeleteError < StandardError; end
                MyPdfDeleteError.new('PDF could not be deleted')
              end

              before do
                expect(File).to receive(:delete).with(pdf_file_path).and_raise(pdf_delete_exception)
                expect(Sidekiq.logger).to receive(:error).with(pdf_delete_exception)
              end
            end
          end
        end

        context 'when PDF file is deleted from another source' do
          it_behaves_like 'a successful job with one document' do
            before do
              expect(File).to receive(:exist?).with(pdf_file_path).and_return(false)
              expect(File).not_to receive(:delete)
            end
          end
        end

        context 'when POA file is still present' do
          context 'and POA deletion succeeds' do
            it_behaves_like 'a successful job with two documents' do
              before do
                expect(File).to receive(:exist?).with(pdf_file_path).and_return(true)
                expect(File).to receive(:delete).with(pdf_file_path)

                expect(File).to receive(:exist?).with(poa_attachment_path).and_return(true)
                expect(File).to receive(:delete).with(poa_attachment_path).and_return(true)
              end
            end
          end

          context 'and PDF deletion fails' do
            it_behaves_like 'a successful job with two documents' do
              let(:pdf_delete_exception) do
                class MyPdfDeleteError < StandardError; end
                MyPdfDeleteError.new('POA could not be deleted')
              end

              before do
                expect(File).to receive(:exist?).with(pdf_file_path).and_return(true)
                expect(File).to receive(:delete).with(pdf_file_path)

                expect(File).to receive(:exist?).with(poa_attachment_path).and_return(true)
                expect(File).to receive(:delete).with(poa_attachment_path).and_raise(pdf_delete_exception)
                expect(Sidekiq.logger).to receive(:error).with(pdf_delete_exception)
              end
            end
          end
        end

        context 'when POA file is deleted from another source' do
          it_behaves_like 'a successful job with two documents' do
            before do
              expect(File).to receive(:exist?).with(pdf_file_path).and_return(true)
              expect(File).to receive(:delete).with(pdf_file_path)

              expect(File).to receive(:exist?).with(poa_attachment_path).and_return(false)
              expect(File).not_to receive(:delete)
            end
          end
        end
      end
    end

    describe 'integration' do
      context 'with one docuemnt' do
        let(:carma_case_id) { 'aB935000000F3VnCAK' }
        let(:claim_guid)    { SecureRandom.uuid }
        let(:claim)         { build(:caregivers_assistance_claim, guid: claim_guid) }
        let(:submission)    { build(:form1010cg_submission, claim_guid: claim_guid, carma_case_id: carma_case_id) }

        before do
          claim.save!
          submission.save!
        end

        after do
          SavedClaim::CaregiversAssistanceClaim.delete_all
          Form1010cg::Submission.delete_all
        end

        it 'sends the claim PDF to CARMA' do
          VCR.use_cassette('carma/auth/token/200', vcr_options[:carma]) do
            VCR.use_cassette('carma/attachments/upload/claim-pdf/201', vcr_options[:carma]) do
              subject.perform(claim_guid)
            end
          end

          expect(File.exist?("tmp/pdfs/10-10CG_#{claim.guid}.pdf")).to eq(false)

          expect(Form1010cg::Submission.find_by(claim_guid: claim_guid)).to eq(nil)
          expect(SavedClaim::CaregiversAssistanceClaim.find_by(guid: claim_guid)).to eq(nil)
        end
      end

      context 'with two documents' do
        let(:carma_case_id)       { 'aB93500000017lDCAQ' }
        let(:poa_attachment_guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
        let(:attachment)          { build(:form1010cg_attachment, guid: poa_attachment_guid) }
        let(:form_data)           { build_claim_data { |d| d['poaAttachmentId'] = poa_attachment_guid }.to_json }
        let(:claim_guid)          { SecureRandom.uuid }
        let(:claim)               { build(:caregivers_assistance_claim, guid: claim_guid, form: form_data) }
        let(:submission)          { build :form1010cg_submission, claim_guid: claim_guid, carma_case_id: carma_case_id }

        before do
          VCR.use_cassette("s3/object/put/#{poa_attachment_guid}/doctors-note.jpg", vcr_options[:aws]) do
            attachment.set_file_data!(
              Rack::Test::UploadedFile.new(
                Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg'),
                'image/jpg'
              )
            )
          end

          attachment.save!
          claim.save!
          submission.save!
        end

        after do
          Form1010cg::Attachment.delete_all
          SavedClaim::CaregiversAssistanceClaim.delete_all
          Form1010cg::Submission.delete_all
        end

        it 'sends the claim PDF and POA attachment to CARMA' do
          VCR.use_cassette("s3/object/get/#{poa_attachment_guid}/doctors-note.jpg", vcr_options[:aws]) do
            VCR.use_cassette('carma/auth/token/200', vcr_options[:carma]) do
              VCR.use_cassette('carma/attachments/upload/claim-pdf-and-poa/201', vcr_options[:carma]) do
                VCR.use_cassette("s3/object/delete/#{poa_attachment_guid}/doctors-note.jpg", vcr_options[:aws]) do
                  subject.perform(claim_guid)
                end
              end
            end
          end

          expect(File.exist?("tmp/#{poa_attachment_guid}_doctors-note.jpg")).to eq(false)
          expect(File.exist?("tmp/pdfs/10-10CG_#{claim_guid}.pdf")).to eq(false)

          expect(Form1010cg::Submission.find_by(claim_guid: claim_guid)).to eq(nil)
          expect(SavedClaim::CaregiversAssistanceClaim.find_by(guid: claim_guid)).to eq(nil)
          expect(Form1010cg::Attachment.find_by(guid: poa_attachment_guid)).to eq(nil)
        end
      end
    end
  end
end
