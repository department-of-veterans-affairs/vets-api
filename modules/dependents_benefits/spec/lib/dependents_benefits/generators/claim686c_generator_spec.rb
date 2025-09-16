# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/generators/claim686c_generator'

RSpec.describe DependentsBenefits::Generators::Claim686cGenerator, type: :model do
  let(:form_data) { create(:dependents_claim).parsed_form }
  let(:parent_id) { 123 }
  let(:generator) { described_class.new(form_data, parent_id) }

  describe '#form_id' do
    it 'returns the correct form_id for 686c' do
      expect(generator.send(:form_id)).to eq('21-686c')
    end
  end

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
    it 'creates a 686c claim' do
      created_claim = generator.generate
      expect(created_claim.form_id).to eq('21-686c')

      parsed_form = JSON.parse(created_claim.form)
      expect(parsed_form['veteran_information']).to eq(form_data['veteran_information'])
    end

    it 'logs a TODO message for claim linking' do
      expect(Rails.logger).to receive(:info).with(match(/Skipping tracking PDF overflow/),
                                                  instance_of(Hash)).at_least(:once)
      expect(Rails.logger).to receive(:info).with(match(/Stamping PDF/)).at_least(:once)
      expect(Rails.logger).to receive(:info).with(match(/TODO: Link claim \d+ to parent #{parent_id}/)).once
      generator.generate
    end
  end
end
