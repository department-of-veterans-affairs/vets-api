# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/generators/claim674_generator'

RSpec.describe DependentsBenefits::Generators::Claim674Generator, type: :model do
  let(:parent_claim) { create(:dependents_claim) }
  let(:form_data) { parent_claim.parsed_form }
  let(:student_data) do
    form_data['dependents_application']['student_information'][0]
  end

  let(:parent_id) { parent_claim.id }
  let(:generator) { described_class.new(form_data, parent_id, student_data) }

  before do
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
  end

  describe '#extract_form_data' do
    let(:extracted_data) { generator.send(:extract_form_data) }

    it 'preserves veteran information' do
      expect(extracted_data['veteran_information'].keys).to eq(%w[birth_date full_name ssn va_file_number])
    end

    it 'includes student-specific data in dependents_application for the specific student' do
      expect(extracted_data['dependents_application']).to have_key('student_information')

      # student_information should contain only this specific student as an array
      expect(extracted_data['dependents_application']['student_information']).to eq(student_data)

      # Verify the student data structure
      student = extracted_data['dependents_application']['student_information']
      expect(student['full_name']['first']).to eq('test')
      expect(student['full_name']['last']).to eq('student')
      expect(student['ssn']).to eq('987654321')
      expect(student['school_information']['name']).to eq('name of trade program')
    end

    it 'includes veteran data' do
      expect(extracted_data['dependents_application']['veteran_contact_information'].keys).to eq(
        %w[
          phone_number
          international_phone_number
          email_address
          electronic_correspondence
          veteran_address
        ]
      )
    end

    it 'does not modify the original form_data' do
      generator.send(:extract_form_data)

      expect(form_data['dependents_application']).to have_key('student_information')
    end
  end

  describe '#generate' do
    let(:mock_group) { create(:saved_claim_group) }

    before do
      allow(SavedClaimGroup).to receive(:find_by).and_return(mock_group)
    end

    it 'creates a 674 claim with extracted student data' do
      created_claim = generator.generate
      expect(created_claim.form_id).to eq('21-674')

      parsed_form = JSON.parse(created_claim.form)
      expect(parsed_form['dependents_application']['student_information']).to eq(student_data)
    end
  end
end
