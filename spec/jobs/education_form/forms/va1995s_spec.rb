# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995s do
  let(:education_benefits_claim) { build(:va1995s).education_benefits_claim }

  subject { described_class.new(education_benefits_claim) }

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission. This technically covers all the helper logic found in the
  # `Form` specs, but are a good safety net for tracking how forms change over time.
  %i[minimal kitchen_sink].each do |application_name|
    test_spool_file('1995s', application_name)
  end

  context '#direct_deposit_type' do
    let(:education_benefits_claim) { create(:va1995s_full_form).education_benefits_claim }
    it 'converts internal keys to text' do
      expect(subject.school['name']).to eq('Test School Name')
      expect(subject.form_type).to eq('CH33')
      expect(subject.form_benefit).to eq('STEM')
      expect(subject.header_form_type).to eq('STEM1995')
    end
  end
end
