# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/generators/claim674_generator'
require 'dependents_benefits/generators/claim686c_generator'

RSpec.describe 'DependentsBenefits Claim Generator Integration', type: :model do
  let(:form_data) { create(:dependents_claim).parsed_form }
  let(:parent_claim_group) { create(:saved_claim_group) }
  let(:parent_claim_id) { parent_claim_group.parent_claim_id }

  describe 'Creating 686c and 674 claims from combined form data' do
    before do
      allow(Rails.logger).to receive(:info)
      allow(SavedClaimGroup).to receive(:find_by).and_return(parent_claim_group)
    end

    context 'when creating a 686c claim' do
      it 'extracts only dependent-related data' do
        generator = DependentsBenefits::Generators::Claim686cGenerator.new(form_data, parent_claim_id)
        claim_686c = generator.generate

        parsed_form = JSON.parse(claim_686c.form)

        # Should include veteran information
        expect(parsed_form['veteran_information']['ssn']).to eq('000000000')

        # Should include dependent data
        expect(parsed_form['dependents_application']['children_to_add']).to be_present

        # Should include veteran contact and household info
        expect(parsed_form['dependents_application']['veteran_contact_information']).to be_present
        expect(parsed_form['dependents_application']['household_income']).to be_present

        # Should NOT include student-specific data
        expect(parsed_form['dependents_application']).not_to have_key('student_information')
        expect(parsed_form['dependents_application']).not_to have_key('school_information')
        expect(parsed_form['dependents_application']).not_to have_key('program_information')

        # Should have correct form_id
        expect(claim_686c.form_id).to eq('21-686C')

        # Should log TODO message for claim linking
        expect(Rails.logger).to have_received(:info).with(
          "TODO: Link claim #{claim_686c.id} to parent #{parent_claim_id}"
        )
      end
    end

    context 'when creating a 674 claim' do
      it 'extracts only student-related data' do
        student_data = form_data.dig('dependents_application', 'student_information', 0)

        generator = DependentsBenefits::Generators::Claim674Generator.new(form_data, parent_claim_id, student_data)
        claim674 = generator.generate

        parsed_form = JSON.parse(claim674.form)

        # Should include veteran information
        expect(parsed_form['veteran_information']['ssn']).to eq('000000000')

        # Should include student-specific data with exactly one student
        expect(parsed_form['dependents_application']['student_information']).to be_present

        student = parsed_form['dependents_application']['student_information']
        expect(student['full_name']['first']).to eq('test')
        expect(student['student_earnings_from_school_year']).to be_present
        expect(student['school_information']).to be_present

        # Should include veteran contact and household info
        expect(parsed_form['dependents_application']['veteran_contact_information']).to be_present

        # Should NOT include dependent-specific data
        expect(parsed_form['dependents_application']).not_to have_key('children_to_add')

        # Should have correct form_id
        expect(claim674.form_id).to eq('21-674')
      end
    end

    context 'when creating both 686c and 674 claims' do
      it 'creates separate claims with appropriate data' do
        # Create both claims
        generator_686c = DependentsBenefits::Generators::Claim686cGenerator.new(form_data, parent_claim_id)
        student_data = form_data.dig('dependents_application', 'student_information', 0)
        generator674 = DependentsBenefits::Generators::Claim674Generator.new(form_data, parent_claim_id, student_data)

        claim_686c = generator_686c.generate
        claim674 = generator674.generate

        # Claims should have different form_ids
        expect(claim_686c.form_id).to eq('21-686C')
        expect(claim674.form_id).to eq('21-674')

        # Should have different form data
        form_686c = JSON.parse(claim_686c.form)
        form674 = JSON.parse(claim674.form)

        expect(form_686c['dependents_application']).not_to have_key('student_information')

        expect(form674['dependents_application']).to have_key('student_information')
      end
    end
  end
end
