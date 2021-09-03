# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DependencyClaim do
  let(:dependency_claim) { create(:dependency_claim_no_vet_information) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
  let(:adopted_child) { FactoryBot.build(:adopted_child_lives_with_veteran) }
  let(:form_674_only) { FactoryBot.build(:form_674_only) }
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
        {
          path: a_string_starting_with('tmp/pdfs/686C-674_'),
          doc_type: '148'
        }
      )

      dependency_claim.add_veteran_info(va_file_number_with_payload)
      dependency_claim.upload_pdf('686C-674')
    end

    it 'uploads to vbms' do
      expect_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload!)

      dependency_claim.add_veteran_info(va_file_number_with_payload)
      dependency_claim.upload_pdf('686C-674')
    end
  end

  describe '#formatted_686_data' do
    it 'returns all data for 686 submissions' do
      claim = described_class.new(form: all_flows_payload.to_json)

      formatted_data = claim.formatted_686_data(va_file_number_with_payload)
      expect(formatted_data).to include(:veteran_information)
    end
  end

  describe '#formatted_674_data' do
    it 'returns all data for 674 submissions' do
      claim = described_class.new(form: all_flows_payload.to_json)

      formatted_data = claim.formatted_674_data(va_file_number_with_payload)
      expect(formatted_data).to include(:dependents_application)
      expect(formatted_data[:dependents_application]).to include(:student_name_and_ssn)
    end
  end

  describe '#submittable_686?' do
    it 'checks if there are 686 flows to process' do
      claim = described_class.new(form: all_flows_payload.to_json)

      expect(claim.submittable_686?).to eq(true)
    end

    it 'returns false if there is no 686 to process' do
      claim = described_class.new(form: form_674_only.to_json)

      expect(claim.submittable_686?).to eq(false)
    end
  end

  describe '#submittable_674?' do
    it 'checks if there are 674 to process' do
      claim = described_class.new(form: all_flows_payload.to_json)

      expect(claim.submittable_674?).to eq(true)
    end

    it 'returns false if there is no 674 to process' do
      claim = described_class.new(form: adopted_child.to_json)

      expect(claim.submittable_674?).to eq(false)
    end
  end

  describe '#regional_office' do
    it 'expects to be empty always' do
      claim = described_class.new(form: adopted_child.to_json)

      expect(claim.regional_office).to eq([])
    end
  end
end
