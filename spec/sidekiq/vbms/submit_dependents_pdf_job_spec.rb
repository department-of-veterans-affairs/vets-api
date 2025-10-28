# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::SubmitDependentsPdfJob do
  # Performance tweak
  before do
    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:pdf_overflow_tracking)
  end

  let(:invalid_dependency_claim) { create(:dependency_claim_no_vet_information) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:vet_info) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => '796043735',
        'va_file_number' => '796043735'
      }
    }
  end
  let(:encrypted_vet_info) { KmsEncrypted::Box.new.encrypt(vet_info.to_json) }

  describe 'sidekiq_retries_exhausted' do
    it 'logs the retries exhausted error with saved_claim_id and the exception object' do
      exception = described_class::Invalid686cClaim.new('boom')
      msg = { 'args' => [12_345, 'encrypted_vet_info', true, false] }

      allow(Rails.logger).to receive(:error)

      job = described_class.new
      job.sidekiq_retries_exhausted_block.call(msg, exception)

      expect(Rails.logger).to have_received(:error).with(
        'VBMS::SubmitDependentsPdfJob failed, retries exhausted!',
        hash_including(saved_claim_id: 12_345)
      )
    end
  end

  describe '#perform' do
    context 'with va_dependents_v2 on' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
      end

      context 'valid submission' do
        before do
          expect(SavedClaim::DependencyClaim)
            .to receive(:find).with(dependency_claim.id)
            .and_return(dependency_claim).at_least(:once)
        end

        context 'attachment processing' do
          let(:temp_path)    { '/tmp/clamav_tmp' }
          let(:fixed_time)   { Time.utc(2025, 1, 1, 12, 0, 0) }
          let(:file_dbl) { double(read: 'bytes', url: 'https://example.com/thing.pdf') }
          let(:attachment) do
            double(Attachment, completed_at: nil, file: file_dbl, doctype: nil, guid: 'abc123', update: true)
          end

          before do
            # avoid PDF generation side-effects; those are tested elsewhere
            allow(dependency_claim).to receive(:upload_pdf)

            allow(dependency_claim).to receive(:persistent_attachments).and_return([attachment])

            # stub filesystem & helpers used by upload_attachments
            allow(Common::FileHelpers).to receive(:generate_clamav_temp_file).and_return(temp_path)
            allow(Common::FileHelpers).to receive(:delete_file_if_exists)
            allow(File).to receive(:rename)

            # when doctype is nil, the job calls get_doc_type(...)
            allow_any_instance_of(VBMS::SubmitDependentsPdfJob).to receive(:get_doc_type).and_return('42')

            allow(Time).to receive(:now).and_return(fixed_time)
          end

          it 'uploads eligible attachments and marks them complete' do
            expect(dependency_claim).to receive(:upload_to_vbms)
              .with(path: "#{temp_path}.pdf", doc_type: '42')

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, false)

            expect(File).to have_received(:rename).with(temp_path, "#{temp_path}.pdf")
            expect(Common::FileHelpers).to have_received(:delete_file_if_exists).with("#{temp_path}.pdf")
            expect(attachment).to have_received(:update).with(completed_at: fixed_time)
          end

          it 'skips upload for unsupported extensions but still marks completed' do
            # same attachment but with a .txt URL -> should NOT call upload_to_vbms
            txt_file = double(read: 'bytes', url: 'https://example.com/note.txt')
            allow(attachment).to receive(:file).and_return(txt_file)

            expect(dependency_claim).not_to receive(:upload_to_vbms)

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, false)

            # no rename or deletion because nothing was written with an allowed extension
            expect(File).not_to have_received(:rename)
            expect(Common::FileHelpers).not_to have_received(:delete_file_if_exists)
            expect(attachment).to have_received(:update).with(completed_at: fixed_time)
          end

          it 'does nothing for attachments already completed' do
            allow(attachment).to receive(:completed_at).and_return(Time.utc(2024, 12, 1))

            expect(dependency_claim).not_to receive(:upload_to_vbms)

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, false)

            # No file ops, no updates
            expect(File).not_to have_received(:rename)
            expect(Common::FileHelpers).not_to have_received(:delete_file_if_exists)
            expect(attachment).not_to have_received(:update)
          end
        end

        context '686 form' do
          it 'creates a 686 PDF' do
            expect(dependency_claim).to receive(:add_veteran_info).with(
              hash_including(vet_info)
            )

            expect(dependency_claim).to receive(:upload_pdf).with('686C-674')

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, false)
          end
        end

        context '674 form' do
          it 'creates a 674 PDF' do
            expect(dependency_claim).to receive(:add_veteran_info).with(
              hash_including(vet_info)
            )

            expect(dependency_claim).to receive(:upload_pdf).with('21-674', doc_type: '142')

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, false, true)
          end
        end

        context 'both 686c and 674 form in claim' do
          it 'creates a PDF for both 686c and 674' do
            expect(dependency_claim).to receive(:add_veteran_info).with(
              hash_including(vet_info)
            )

            expect(dependency_claim).to receive(:upload_pdf).with('686C-674')
            expect(dependency_claim).to receive(:upload_pdf).with('21-674', doc_type: '142')

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, true)
          end
        end
      end
    end

    context 'with va_dependents_v2 off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
      end

      context 'valid submission' do
        before do
          expect(SavedClaim::DependencyClaim)
            .to receive(:find).with(dependency_claim.id)
            .and_return(dependency_claim).at_least(:once)
        end

        context '686 form' do
          it 'creates a 686 PDF' do
            expect(dependency_claim).to receive(:add_veteran_info).with(
              hash_including(vet_info)
            )

            expect(dependency_claim).to receive(:upload_pdf).with('686C-674')

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, false)
          end
        end

        context '674 form' do
          it 'creates a 674 PDF' do
            expect(dependency_claim).to receive(:add_veteran_info).with(
              hash_including(vet_info)
            )

            expect(dependency_claim).to receive(:upload_pdf).with('21-674', doc_type: '142')

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, false, true)
          end
        end

        context 'both 686c and 674 form in claim' do
          it 'creates a PDF for both 686c and 674' do
            expect(dependency_claim).to receive(:add_veteran_info).with(
              hash_including(vet_info)
            )

            expect(dependency_claim).to receive(:upload_pdf).with('686C-674')
            expect(dependency_claim).to receive(:upload_pdf).with('21-674', doc_type: '142')

            described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, true)
          end
        end
      end
    end
  end

  describe '#get_doc_type' do
    subject(:resolved_type) { described_class.new.send(:get_doc_type, guid, parsed_form) }

    let(:guid) { 'abc123' }

    context 'when spouse documents match and have an evidence type' do
      let(:parsed_form) do
        {
          'dependents_application' => {
            'spouse_supporting_documents' => [
              { 'confirmation_code' => 'abc123' }
            ],
            'spouse_evidence_document_type' => '134',
            # Even if child also matches, spouse should win
            'child_supporting_documents' => [
              { 'confirmation_code' => 'abc123' }
            ],
            'child_evidence_document_type' => '999'
          }
        }
      end

      it 'returns the spouse evidence type (spouse precedence)' do
        expect(resolved_type).to eq('134')
      end
    end

    context 'when spouse does not match but child does' do
      let(:parsed_form) do
        {
          'dependents_application' => {
            'spouse_supporting_documents' => [
              { 'confirmation_code' => 'zzz999' }
            ],
            'spouse_evidence_document_type' => '134',
            'child_supporting_documents' => [
              { 'confirmation_code' => 'abc123' }
            ],
            'child_evidence_document_type' => '777'
          }
        }
      end

      it 'returns the child evidence type' do
        expect(resolved_type).to eq('777')
      end
    end

    context 'when spouse matches but spouse evidence type is blank' do
      let(:parsed_form) do
        {
          'dependents_application' => {
            'spouse_supporting_documents' => [
              { 'confirmation_code' => 'abc123' }
            ],
            'spouse_evidence_document_type' => '', # blank -> not present?
            'child_supporting_documents' => [],
            'child_evidence_document_type' => nil
          }
        }
      end

      it 'falls through and returns default "10"' do
        expect(resolved_type).to eq('10')
      end
    end

    context 'when neither spouse nor child matches' do
      let(:parsed_form) do
        {
          'dependents_application' => {
            'spouse_supporting_documents' => [
              { 'confirmation_code' => 'nope' }
            ],
            'spouse_evidence_document_type' => '134',
            'child_supporting_documents' => [
              { 'confirmation_code' => 'also-nope' }
            ],
            'child_evidence_document_type' => '777'
          }
        }
      end

      it 'returns the default "10"' do
        expect(resolved_type).to eq('10')
      end
    end

    context 'when supporting document arrays are missing or empty' do
      let(:parsed_form) do
        {
          'dependents_application' => {
            'spouse_supporting_documents' => nil,
            'spouse_evidence_document_type' => '134',
            'child_supporting_documents' => [],
            'child_evidence_document_type' => '777'
          }
        }
      end

      it 'returns the default "10"' do
        expect(resolved_type).to eq('10')
      end
    end
  end

  context 'with an invalid submission' do
    it 'sends an error message if no claim exists' do
      job = described_class.new
      expect(Rails.logger).to receive(:warn).at_least(:once)

      expect do
        job.perform('non-existent-claim', encrypted_vet_info, true, false)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises an error if there is nothing in the dependents_application is empty' do
      expect(SavedClaim::DependencyClaim)
        .to receive(:find).with(invalid_dependency_claim.id)
        .and_return(invalid_dependency_claim).at_least(:once)

      job = described_class.new

      expect(Rails.logger).to receive(:error).at_least(:once)

      vet_info['veteran_information'].delete('ssn')
      expect do
        job.perform(invalid_dependency_claim.id, encrypted_vet_info, true, false)
      end.to raise_error(VBMS::SubmitDependentsPdfJob::Invalid686cClaim)
    end
  end
end
