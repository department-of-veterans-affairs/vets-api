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
    context 'with a valid 686 submission' do
      it 'creates a 686 PDF' do
        expect_any_instance_of(SavedClaim::DependencyClaim).to receive(:add_veteran_info).with(
          vet_info
        )

        described_class.new.perform(dependency_claim.id, encrypted_vet_info, true, false)
      end
    end

    context 'with a valid 674 submission' do
      it 'creates a 674 PDF' do
        expect_any_instance_of(SavedClaim::DependencyClaim).to receive(:add_veteran_info).with(
          vet_info
        )

        described_class.new.perform(dependency_claim.id, encrypted_vet_info, false, true)
      end
    end

    context 'with an invalid submission' do
      it 'sends an error message if no claim exists' do
        job = described_class.new

        expect(job).to receive(:send_error_to_sentry).with(
          anything,
          'non-existent-claim'
        )

        job.perform('non-existent-claim', encrypted_vet_info, true, false)
      end

      it 'raises an error if there is nothing in the dependents_application is empty' do
        job = described_class.new

        expect(job).to receive(:send_error_to_sentry).with(
          an_instance_of(VBMS::SubmitDependentsPdfEncryptedJob::Invalid686cClaim),
          an_instance_of(Integer)
        )

        vet_info['veteran_information'].delete('ssn')
        job.perform(invalid_dependency_claim.id, encrypted_vet_info, true, false)
      end

      it 'returns false' do
        job = described_class.new.perform('f', encrypted_vet_info, true, false)

        expect(job).to eq(false)
      end
    end
  end
end
