# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DependencyClaim do
  let(:dependency_claim) { create(:dependency_claim_no_vet_information) }
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

  describe '#format_and_uplad_pdf' do
    it 'calls upload to vbms' do
      expect_any_instance_of(described_class).to receive(:upload_to_vbms).with(
        a_string_starting_with('tmp/pdfs/686C-674_')
      )

      dependency_claim.add_veteran_info(va_file_number_with_payload)
      dependency_claim.upload_pdf
    end

    it 'uploads to vbms' do
      expect_any_instance_of(ClaimsApi::VbmsUploader).to receive(:upload!)

      dependency_claim.add_veteran_info(va_file_number_with_payload)
      dependency_claim.upload_pdf
    end
  end
end
