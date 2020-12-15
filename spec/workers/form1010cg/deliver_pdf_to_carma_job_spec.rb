# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::DeliverPdfToCARMAJob do
  it 'inherits Sidekiq::Worker' do
    expect(described_class.ancestors).to include(Sidekiq::Worker)
  end

  describe '#perform' do
    describe 'unit' do
      let(:claim_guid) { SecureRandom.uuid }
      let(:pdf_file_path) { "tmp/pdfs/10-10CG_#{claim_guid}.pdf" }
      let(:claim) { build(:caregivers_assistance_claim, guid: claim_guid) }
      let(:submission) { build(:form1010cg_submission, claim_guid: claim_guid) }

      before do
        submission.claim = claim
        submission.save!
      end

      after do
        claim.destroy unless claim.destroyed?
        submission.destroy unless claim.destroyed?
      end

      shared_examples 'a successful job' do
        let(:attachments) { double('attachments') }
        let(:auditor) { double('auditor') }

        before do
          expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(:to_pdf).and_return(pdf_file_path)
          expect(Form1010cg::Service).to receive(:submit_attachment!).with(
            submission.carma_case_id,
            claim.veteran_data['fullName'],
            '10-10CG',
            pdf_file_path
          ).and_return(attachments)

          expect(attachments).to receive(:to_hash).and_return(:ATTACHMENTS_HASH)

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

        it 'processes attachment' do
          subject.perform(claim_guid)
        end
      end

      it 'requires a claim_guid' do
        expect { subject.perform }.to raise_error(ArgumentError) do |error|
          expect(error.message).to eq('wrong number of arguments (given 0, expected 1)')
        end
      end

      context 'when submission is not found' do
        let(:expected_exception_class) { ActiveRecord::RecordNotFound }

        before { submission.delete } # delete the submission but not the claim

        it 'raises error' do
          expect { subject.perform(SecureRandom.uuid) }.to raise_error(expected_exception_class) do |error|
            expect(error.message).to include('Couldn\'t find Form1010cg::Submission')
          end
        end
      end

      context 'when claim is not found' do
        let(:expected_exception_class) { described_class::MissingClaimException }

        before { claim.delete } # delete the claim but not the submission

        it 'raises error' do
          expect { subject.perform(claim_guid) }.to raise_error(expected_exception_class) do |error|
            expect(error.message).to eq('Could not find a claim associated to this submission')
          end
        end
      end

      context 'when PDF generation fails' do
        let(:pdf_generation_exception) do
          class MyPdfGenerationError < StandardError; end
          MyPdfGenerationError.new('PDF could not be generated')
        end

        before do
          expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(
            :to_pdf
          ).and_raise(
            pdf_generation_exception
          )
        end

        it 'raises error' do
          expect { subject.perform(claim_guid) }.to raise_error(pdf_generation_exception.class) do |error|
            expect(error.message).to eq(pdf_generation_exception.message)
          end
        end
      end

      it_behaves_like 'a successful job'

      describe 'cleanup' do
        context 'when PDF is still present' do
          before do
            expect(File).to receive(:exist?).with(pdf_file_path).and_return(true)
          end

          context 'and PDF deletion succeeds' do
            it_behaves_like 'a successful job' do
              before do
                expect(File).to receive(:delete).with(pdf_file_path).and_return(true)
              end
            end
          end

          context 'and PDF deletion fails' do
            let(:pdf_delete_exception) do
              class MyPdfDeleteError < StandardError; end
              MyPdfDeleteError.new('PDF could not be deleted')
            end

            it_behaves_like 'a successful job' do
              before do
                expect(File).to receive(:delete).with(pdf_file_path).and_raise(pdf_delete_exception)
                expect(Sidekiq.logger).to receive(:error).with(pdf_delete_exception)
              end
            end
          end
        end

        context 'when PDF is deleted from another source' do
          it_behaves_like 'a successful job' do
            before do
              expect(File).to receive(:exist?).with(pdf_file_path).and_return(false)
              expect(File).not_to receive(:delete)
            end
          end
        end
      end
    end

    describe 'integration' do
      timestamp = DateTime.parse('2020-06-29T06:48:59-04:00') # Match VCR

      let(:claim_guid) { 'c41b7fe0-f1f3-4611-9c56-a97fb3884cf8' } # Match VCR
      let(:file_path) { "tmp/pdfs/10-10CG_#{claim_guid}.pdf" }
      let(:claim) { build(:caregivers_assistance_claim, guid: claim_guid) }

      let(:submission) do
        build(
          :form1010cg_submission,
          claim_guid: claim_guid,
          carma_case_id: 'aB935000000F3VnCAK' # Match VCR
        )
      end

      let(:vcr_options) do
        {
          auth: {
            record: :none,
            allow_unused_http_interactions: false
          },
          attachments: {
            record: :none,
            allow_unused_http_interactions: false,
            match_requests_on: %i[method uri host path body]
          }
        }
      end

      before do
        # There should be existing records when job is called
        submission.claim = claim
        submission.save!

        # Create the file contents of the claim to match the request body in the VCR (carma/attachments/upload/201)
        Dir.mkdir('tmp/pdfs') unless File.exist?('tmp/pdfs')
        File.open(file_path, 'w') { |f| f.write('<PDF_CONTENTS>') }
        expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(:to_pdf).and_return(file_path)
      end

      after do
        # After processing, it should delete all resources
        expect { submission.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { claim.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(File.exist?(file_path)).to eq(false)

        # Test cleanup
        claim.destroy unless claim.destroyed?
        submission.destroy unless claim.destroyed?
      end

      it 'processes attachment', run_at: timestamp.iso8601 do
        VCR.use_cassette('carma/auth/token/200', vcr_options[:auth]) do
          VCR.use_cassette('carma/attachments/upload/201', vcr_options[:attachments]) do
            subject.perform(claim_guid)
          end
        end
      end
    end
  end
end
