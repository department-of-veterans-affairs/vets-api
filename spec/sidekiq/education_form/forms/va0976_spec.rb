# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA0976 do
  subject { described_class.new(application) }

  before do
    allow_any_instance_of(EducationForm::Forms::Base).to receive(:format).and_return('')
    allow_any_instance_of(SavedClaim::EducationBenefits::VA0976).to receive(:form_matches_schema).and_return(true)
  end

  let(:application) { create(:va0976).education_benefits_claim }

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
    expect(subject.additional_certifying_officials.size).to eq(1)
    expect(subject.read_only_certifying_officials.size).to eq(1)
  end

  it 'handles arrays with data' do
    form_data = {
      'designatingOfficial' => {
        'fullName' => { 'first' => 'John', 'last' => 'Doe' },
        'title' => 'Official',
        'emailAddress' => 'test@example.com'
      },
      'institutionDetails' => {
        'hasVaFacilityCode' => true,
        'facilityCode' => '12345678',
        'institutionName' => 'Test U',
        'institutionAddress' => {
          'country' => 'USA',
          'street' => '123 Main St',
          'city' => 'Anytown',
          'state' => 'CA',
          'postalCode' => '12345'
        }
      },
      'primaryOfficialDetails' => {
        'fullName' => { 'first' => 'Jane', 'last' => 'Smith' },
        'title' => 'Official',
        'emailAddress' => 'test@example.com'
      },
      'primaryOfficialTraining' => {
        'trainingCompletionDate' => '2024-01-01',
        'trainingExempt' => false
      },
      'primaryOfficialBenefitStatus' => {
        'hasVaEducationBenefits' => true
      },
      'additionalCertifyingOfficials' => [
        {
          'additionalCertifyingOfficialsDetails' => {
            'fullName' => { 'first' => 'Test', 'last' => 'Official' },
            'title' => 'Role',
            'emailAddress' => 'test@example.com'
          }
        }
      ],
      'hasReadOnlyCertifyingOfficial' => true,
      'readOnlyCertifyingOfficial' => [
        {
          'fullName' => { 'first' => 'RCO', 'last' => 'One' }
        }
      ],
      'remarks' => 'Some remarks',
      'statementOfTruthSignature' => 'John Doe',
      'dateSigned' => '2024-01-01'
    }

    saved_claim = build(:va0976, form: form_data.to_json)
    allow(saved_claim).to receive(:form_matches_schema).and_return(true)
    saved_claim.save!(validate: false)
    saved_claim.build_education_benefits_claim if saved_claim.education_benefits_claim.nil?
    saved_claim.education_benefits_claim.save!(validate: false)
    app = saved_claim.education_benefits_claim
    form = described_class.new(app)

    expect(form.additional_certifying_officials.size).to eq(1)
    expect(form.read_only_certifying_officials.size).to eq(1)
    expect(form.read_only_certifying_official?).to be(true)
    expect(form.remarks).to eq('Some remarks')
  end

  it 'handles empty arrays with fallback' do
    form_data = {
      'designatingOfficial' => {
        'fullName' => { 'first' => 'John', 'last' => 'Doe' },
        'title' => 'Official',
        'emailAddress' => 'test@example.com'
      },
      'institutionDetails' => {
        'hasVaFacilityCode' => true,
        'facilityCode' => '12345678',
        'institutionName' => 'Test U',
        'institutionAddress' => {
          'country' => 'USA',
          'street' => '123 Main St',
          'city' => 'Anytown',
          'state' => 'CA',
          'postalCode' => '12345'
        }
      },
      'primaryOfficialDetails' => {
        'fullName' => { 'first' => 'Jane', 'last' => 'Smith' },
        'title' => 'Official',
        'emailAddress' => 'test@example.com'
      },
      'primaryOfficialTraining' => {
        'trainingCompletionDate' => '2024-01-01',
        'trainingExempt' => false
      },
      'primaryOfficialBenefitStatus' => {
        'hasVaEducationBenefits' => true
      },
      'statementOfTruthSignature' => 'John Doe',
      'dateSigned' => '2024-01-01'
    }

    saved_claim = build(:va0976, form: form_data.to_json)
    allow(saved_claim).to receive(:form_matches_schema).and_return(true)
    saved_claim.save!(validate: false)
    saved_claim.build_education_benefits_claim if saved_claim.education_benefits_claim.nil?
    saved_claim.education_benefits_claim.save!(validate: false)
    app = saved_claim.education_benefits_claim
    form = described_class.new(app)

    expect(form.additional_certifying_officials).to eq([])
    expect(form.read_only_certifying_officials).to eq([])
  end

  it 'reads remarks and signature fields' do
    expect(subject.remarks).to eq('Test remarks')
    expect(subject.statement_of_truth_signature).to eq('John A Doe')
    expect(subject.date_signed).to eq('2024-03-15')
  end

  it 'reads remarks when present' do
    form_data = JSON.parse(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0976',
                                           'minimal.json').read)
    form_data['remarks'] = 'Test remarks text'
    saved_claim = build(:va0976, form: form_data.to_json)
    allow(saved_claim).to receive(:form_matches_schema).and_return(true)
    saved_claim.save!(validate: false)
    saved_claim.build_education_benefits_claim if saved_claim.education_benefits_claim.nil?
    saved_claim.education_benefits_claim.save!(validate: false)
    app = saved_claim.education_benefits_claim
    form = described_class.new(app)

    expect(form.remarks).to eq('Test remarks text')
  end

  it 'handles read_only_certifying_official? boolean' do
    expect(subject.read_only_certifying_official?).to be(true)
  end

  it 'handles read_only_certifying_official? when true' do
    form_data = JSON.parse(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0976',
                                           'minimal.json').read)
    form_data['hasReadOnlyCertifyingOfficial'] = true
    saved_claim = build(:va0976, form: form_data.to_json)
    allow(saved_claim).to receive(:form_matches_schema).and_return(true)
    saved_claim.save!(validate: false)
    saved_claim.build_education_benefits_claim if saved_claim.education_benefits_claim.nil?
    saved_claim.education_benefits_claim.save!(validate: false)
    app = saved_claim.education_benefits_claim
    form = described_class.new(app)

    expect(form.read_only_certifying_official?).to be(true)
  end

  it 'exposes the header form type' do
    expect(subject.header_form_type).to eq('V0976')
  end

  it 'handles optional fields when absent' do
    form_data = {
      'designatingOfficial' => {
        'fullName' => { 'first' => 'John', 'last' => 'Doe' },
        'title' => 'Official',
        'emailAddress' => 'test@example.com'
      },
      'institutionDetails' => {
        'hasVaFacilityCode' => false,
        'facilityCode' => '12345678',
        'institutionName' => 'Test U',
        'institutionAddress' => {
          'country' => 'USA',
          'street' => '123 Main St',
          'city' => 'Anytown',
          'state' => 'CA',
          'postalCode' => '12345'
        }
      },
      'primaryOfficialDetails' => {
        'fullName' => { 'first' => 'Jane', 'last' => 'Smith' },
        'title' => 'Official',
        'emailAddress' => 'test@example.com'
      },
      'primaryOfficialTraining' => {
        'trainingCompletionDate' => '2024-01-01',
        'trainingExempt' => true
      },
      'primaryOfficialBenefitStatus' => {
        'hasVaEducationBenefits' => false
      },
      'statementOfTruthSignature' => 'John Doe',
      'dateSigned' => '2024-01-01'
    }

    saved_claim = build(:va0976, form: form_data.to_json)
    allow(saved_claim).to receive(:form_matches_schema).and_return(true)
    saved_claim.save!(validate: false)
    saved_claim.build_education_benefits_claim if saved_claim.education_benefits_claim.nil?
    saved_claim.education_benefits_claim.save!(validate: false)
    app = saved_claim.education_benefits_claim
    form = described_class.new(app)

    expect(form.va_facility_code?).to be(false)
    expect(form.training_exempt).to be(true)
    expect(form.va_education_benefits?).to be(false)
    expect(form.additional_certifying_officials).to eq([])
    expect(form.read_only_certifying_officials).to eq([])
    expect(form.read_only_certifying_official?).to be_nil
    expect(form.remarks).to be_nil
  end

  it 'initializes correctly' do
    expect(subject.instance_variable_get(:@education_benefits_claim)).to eq(application)
    expect(subject.instance_variable_get(:@applicant)).to eq(application.parsed_form)
  end
end
