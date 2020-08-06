# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::SubmitDependentsPDFJob do
  let(:invalid_dependency_claim) { create(:dependency_claim_no_vet_information) }
  let(:dependency_claim) { create(:dependency_claim) }

  let(:va_file_number_with_payload) do
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

  describe '#perform' do
    context 'with a valid submission' do
      it 'creates a PDF' do
        expect_any_instance_of(SavedClaim::DependencyClaim).to receive(:add_veteran_info).with(
          va_file_number_with_payload
        )

        described_class.new.perform(dependency_claim.id, va_file_number_with_payload)
      end
    end

    context 'with an invalid submission' do
      it 'sends an error message if no claim exists' do
        job = described_class.new

        expect(job).to receive(:send_error_to_sentry).with(
          anything,
          nil
        )

        job.perform('non-existant-claim', va_file_number_with_payload)
      end

      it 'raises an error if there is nothing in the dependents_application is empty' do
        job = described_class.new

        expect(job).to receive(:send_error_to_sentry).with(
          an_instance_of(VBMS::SubmitDependentsPDFJob::Invalid686cClaim),
          an_instance_of(Integer)
        )

        job.perform(invalid_dependency_claim.id, va_file_number_with_payload)
      end

      it 'returns false' do
        job = described_class.new.perform('f', va_file_number_with_payload)

        expect(job).to eq(false)
      end
    end
  end
end
