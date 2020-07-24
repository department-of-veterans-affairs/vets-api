# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DependencyClaim do
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

  it '#format_and_upload_pdf' do
    expect_any_instance_of(described_class).to receive(:upload_to_vbms).with(
      a_string_starting_with('tmp/pdfs/686C-674_'), vet_info)

    dependency_claim.format_and_upload_pdf(vet_info)
  end

  it 'fills out form' do
    expect(PdfFill::Filler).to receive(:fill_form).with(dependency_claim)

    described_class.new.perform(dependency_claim.id, vet_info)
  end
end