# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10282 do
  subject { described_class.new(application) }

  let(:application) { create(:va10282).education_benefits_claim }

  %w[minimal].each do |test_application|
    test_excel_file('10282', test_application)
  end

  it 'exposes the header form type' do
    expect(subject.header_form_type).to eq('V10282')
  end
end
