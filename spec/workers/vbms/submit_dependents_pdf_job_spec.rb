# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::SubmitDependentsPDFJob do
  let(:gi_bill_feedback) { create(:gi_bill_feedback) }
  let(:claim) { double('claim') }
  let(:dependency_claim) { create(:dependency_claim_no_vet_information) }
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

  before { allow(claim).to receive(:id).and_return('686C-674') }

  describe '#perform' do
    context 'with a valid submission' do
      it 'creates a PDF' do
        expect_any_instance_of(described_class).to receive(:to_pdf).with(
          dependency_claim, vet_info
        )

        described_class.new.perform(dependency_claim.id, vet_info)
      end

      it 'uploads to VBMS' do
        expect_any_instance_of(described_class).to receive(:upload_to_vbms).with(
          a_string_starting_with('tmp/pdfs/686C-674_'), vet_info, dependency_claim.id
        )

        described_class.new.perform(dependency_claim.id, vet_info)
      end

      it 'fills out form' do
        expect(PdfFill::Filler).to receive(:fill_form).with(dependency_claim)

        described_class.new.perform(dependency_claim.id, vet_info)
      end

      # it 'returns vbms upload hash' do
      #   VCR.use_cassette('vbms/submit_dependents_pdf_job/perform') do
      #     job = described_class.new.perform(dependency_claim.id, vet_info)
      #
      #     expect(job).to include(
      #                      :vbms_new_document_version_ref_id,
      #                      :vbms_document_series_ref_id
      #                    )
      #   end
      # end
    end

    context 'with an invalid submission' do
      it 'sends an error message if no claim exists' do
        job = described_class.new

        expect(job).to receive(:send_error_to_sentry).with(
          anything,
          'f'
        )

        job.perform('f', vet_info)
      end

      it 'returns false' do
        job = described_class.new.perform('f', vet_info)

        expect(job).to eq(false)
      end
    end
  end
end
