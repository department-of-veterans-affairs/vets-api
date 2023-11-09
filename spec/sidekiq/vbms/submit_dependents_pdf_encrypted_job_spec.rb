# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::SubmitDependentsPdfEncryptedJob do
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

  describe '#perform' do
    context 'valid submission' do
      before do
        expect(SavedClaim::DependencyClaim)
          .to receive(:find).with(dependency_claim.id)
          .and_return(dependency_claim)
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

  context 'with an invalid submission' do
    it 'sends an error message if no claim exists' do
      job = described_class.new

      expect(job).to receive(:send_error_to_sentry).with(
        ActiveRecord::RecordNotFound,
        'non-existent-claim'
      )

      expect do
        job.perform('non-existent-claim', encrypted_vet_info, true, false)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises an error if there is nothing in the dependents_application is empty' do
      expect(SavedClaim::DependencyClaim)
        .to receive(:find).with(invalid_dependency_claim.id)
        .and_return(invalid_dependency_claim)

      job = described_class.new

      expect(job).to receive(:send_error_to_sentry).with(
        an_instance_of(VBMS::SubmitDependentsPdfEncryptedJob::Invalid686cClaim),
        an_instance_of(Integer)
      )

      vet_info['veteran_information'].delete('ssn')
      expect do
        job.perform(invalid_dependency_claim.id, encrypted_vet_info, true,
                    false)
      end.to raise_error(VBMS::SubmitDependentsPdfEncryptedJob::Invalid686cClaim)
    end
  end
end
