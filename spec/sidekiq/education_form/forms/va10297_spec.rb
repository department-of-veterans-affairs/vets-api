# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10297 do
  subject { described_class.new(application) }

  let(:application) { create(:va10297_full_form).education_benefits_claim }

  it 'exposes the header form type' do
    expect(subject.header_form_type).to eq('V10297')
  end

  it 'exposes the bank info' do
    expect(subject.bank_routing_number).to eq('123456789')
    expect(subject.bank_account_number).to eq('123456')
    expect(subject.bank_account_type).to eq('checking')
  end

  it 'exposes the education level' do
    expect(subject.education_level_name).to eq('Bachelor’s degree')
  end

  it 'exposes the salary' do
    expect(subject.salary_text).to eq('$20,000-$35,000')
  end

  %w[simple kitchen_sink].each do |form|
    test_spool_file('10297', form)
  end
end
