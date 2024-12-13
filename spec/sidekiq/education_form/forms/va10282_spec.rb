# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10282 do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { build(:va10282).education_benefits_claim }

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission in CSV format
  %i[minimal].each do |application_name|
    test_excel_file('10282', application_name)
  end

  describe 'mapped fields' do
    let(:education_benefits_claim) { create(:va10282).education_benefits_claim }

    describe '#military_affiliation' do
      it 'maps military types correctly' do
        expect(subject.military_affiliation).to eq('Veteran')
      end
    end

    describe '#name fields' do
      it 'correctly formats full name' do
        expect(subject.name).to eq('a c')
        expect(subject.first_name).to eq('a')
        expect(subject.last_name).to eq('c')
      end
    end

    describe '#phone_number' do
      it 'returns phone number' do
        expect(subject.phone_number).to eq('1234567890')
      end
    end

    describe '#email_address' do
      it 'returns the email address' do
        expect(subject.email_address).to eq('a@c.com')
      end
    end

    describe '#location' do
      it 'returns the correct country' do
        expect(subject.country).to eq('United States')
      end

      it 'returns the correct state' do
        expect(subject.state).to eq('FL')
      end
    end

    describe '#race_ethnicity' do
      it 'returns the correct race/ethnicity' do
        expect(subject.race_ethnicity).to eq('Black or African American')
      end
    end

    describe '#gender' do
      it 'returns the correct gender' do
        expect(subject.gender).to eq('Male')
      end
    end

    describe '#education_level' do
      it 'returns the correct education level' do
        expect(subject.education_level).to eq("Master's Degree")
      end
    end

    describe '#technology_industry' do
      it 'maps tech areas correctly' do
        expect(subject.technology_industry).to eq('Computer Programming')
      end
    end

    describe '#salary' do
      it 'maps salary ranges correctly' do
        expect(subject.salary).to eq('More than $75,000')
      end
    end

    describe '#employment_status' do
      it 'returns Yes when employed' do
        expect(subject.employment_status).to eq('Yes')
      end
    end
  end
end
