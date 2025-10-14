# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA8794 do
  subject { described_class.new(application) }

  before do
    allow_any_instance_of(EducationForm::Forms::Base).to receive(:format).and_return('')
  end

  let(:application) { create(:va8794).education_benefits_claim }

  it 'reads designating official fields' do
    expect(subject.designating_official_name).to eq({ 'first' => 'John', 'middle' => 'A', 'last' => 'Doe' })
    expect(subject.designating_official_title).to eq('Designating Official')
    expect(subject.designating_official_email).to eq('john.doe@example.com')
  end

  it 'reads institution details' do
    expect(subject.institution_name).to eq('Test University')
    expect(subject.facility_code).to eq('12345678')
    expect(subject.va_facility_code?).to be(true)
  end

  it 'reads primary official fields' do
    expect(subject.primary_official_name).to eq({ 'first' => 'Jane', 'middle' => 'B', 'last' => 'Smith' })
    expect(subject.primary_official_title).to eq('Primary Certifying Official')
    expect(subject.primary_official_email).to eq('jane.smith@example.com')
  end

  it 'reads training and benefit fields' do
    expect(subject.training_completion_date).to eq('2024-03-15')
    expect(subject.training_exempt).to be(false)
    expect(subject.va_education_benefits?).to be(true)
  end

  it 'handles arrays and booleans' do
    expect(subject.additional_certifying_officials.size).to eq(2)
    expect(subject.read_only_certifying_officials.size).to eq(2)
  end

  it 'reads remarks and signature fields even when absent' do
    expect(subject.remarks).to eq('lorem ipsum dolor sit amet')
    expect(subject.statement_of_truth_signature).to eq('John A Doe')
    expect(subject.date_signed).to eq('2024-03-15')
  end

  it 'exposes the header form type' do
    expect(subject.header_form_type).to eq('V8794')
  end
end
