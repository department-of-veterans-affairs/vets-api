# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/generators/claim686c_generator'

RSpec.describe DependentsBenefits::Generators::Claim686cGenerator, type: :model do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
  end

  let(:parent_claim) { create(:dependents_claim) }
  let(:form_data) { parent_claim.parsed_form }
  let(:parent_id) { parent_claim.id }
  let(:generator) { described_class.new(form_data, parent_id) }

  describe '#extract_form_data' do
    let(:extracted_data) { generator.send(:extract_form_data) }

    it 'preserves veteran information' do
      expect(extracted_data['veteran_information'].keys).to include(*%w[birth_date full_name ssn va_file_number])
    end

    it 'preserves non-student data in dependents_application' do
      expect(extracted_data['dependents_application']['veteran_contact_information']).to eq(
        form_data['dependents_application']['veteran_contact_information']
      )
      expect(extracted_data['dependents_application']['household_income']).to be(true)
    end

    it 'removes student-specific data from dependents_application' do
      student_keys = %w[
        student_information
        student_name_and_ssn
        school_information
        program_information
      ]

      student_keys.each do |key|
        expect(extracted_data['dependents_application']).not_to have_key(key)
      end
    end

    it 'does not modify the original form_data' do
      generator.send(:extract_form_data)
      expect(form_data['dependents_application']).to have_key('student_information')
    end
  end

  describe '#generate' do
    let!(:parent_claim_group) do
      create(:saved_claim_group,
             claim_group_guid: parent_claim.guid,
             parent_claim_id: parent_claim.id,
             saved_claim_id: parent_claim.id)
    end

    it 'creates a 686c claim' do
      created_claim = generator.generate
      expect(created_claim.form_id).to eq('21-686C')

      parsed_form = JSON.parse(created_claim.form)
      expect(parsed_form['veteran_information']).to eq(form_data['veteran_information'])

      # Verify that a new claim group was created linking the new claim to the parent
      new_claim_group = SavedClaimGroup.find_by(
        parent_claim_id: parent_claim.id,
        saved_claim_id: created_claim.id
      )
      expect(new_claim_group).to be_present
      expect(new_claim_group.claim_group_guid).to eq(parent_claim.guid)
    end
  end
end
