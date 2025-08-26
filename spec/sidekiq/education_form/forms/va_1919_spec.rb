# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1919 do
  let(:education_benefits_claim) { create(:education_benefits_claim, :form1919) }
  let(:form_data) do
    JSON.parse(
      Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1919', 'minimal.json').read
    )
  end

  before do
    education_benefits_claim.update!(parsed_form: form_data)
  end

  subject { described_class.new(education_benefits_claim) }

  describe '#institution_name' do
    it 'returns the institution name' do
      expect(subject.institution_name).to eq('Test University')
    end
  end

  describe '#facility_code' do
    it 'returns the facility code' do
      expect(subject.facility_code).to eq('12345678')
    end
  end

  describe '#certifying_official_name' do
    it 'returns the full name of the certifying official' do
      expect(subject.certifying_official_name).to eq('John Doe')
    end

    context 'when certifying official is missing' do
      before do
        form_data.delete('certifyingOfficial')
        education_benefits_claim.update!(parsed_form: form_data)
      end

      it 'returns empty string' do
        expect(subject.certifying_official_name).to eq('')
      end
    end
  end

  describe '#certifying_official_role' do
    it 'returns the role level' do
      expect(subject.certifying_official_role).to eq('certifying official')
    end

    context 'when role is other' do
      before do
        form_data['certifyingOfficial']['role'] = {
          'level' => 'other',
          'other' => 'Custom Role'
        }
        education_benefits_claim.update!(parsed_form: form_data)
      end

      it 'returns the other field value' do
        expect(subject.certifying_official_role).to eq('Custom Role')
      end
    end

    context 'when role is missing' do
      before do
        form_data['certifyingOfficial'].delete('role')
        education_benefits_claim.update!(parsed_form: form_data)
      end

      it 'returns empty string' do
        expect(subject.certifying_official_role).to eq('')
      end
    end
  end

  describe '#proprietary_conflicts_count' do
    it 'returns the number of proprietary conflicts' do
      expect(subject.proprietary_conflicts_count).to eq(2)
    end

    it 'limits to maximum of 2' do
      form_data['proprietaryProfitConflicts'] << {
        'affiliatedIndividuals' => {
          'first' => 'Third',
          'last' => 'Person',
          'title' => 'Manager',
          'individualAssociationType' => 'va'
        }
      }
      education_benefits_claim.update!(parsed_form: form_data)
      expect(subject.proprietary_conflicts_count).to eq(2)
    end

    context 'when no conflicts exist' do
      before do
        form_data['proprietaryProfitConflicts'] = []
        education_benefits_claim.update!(parsed_form: form_data)
      end

      it 'returns 0' do
        expect(subject.proprietary_conflicts_count).to eq(0)
      end
    end
  end

  describe '#proprietary_conflicts' do
    it 'returns the proprietary conflicts array' do
      conflicts = subject.proprietary_conflicts
      expect(conflicts).to be_an(Array)
      expect(conflicts.length).to eq(2)
      expect(conflicts.first['affiliatedIndividuals']['first']).to eq('Jane')
    end

    it 'returns only first 2 conflicts' do
      form_data['proprietaryProfitConflicts'] << {
        'affiliatedIndividuals' => {
          'first' => 'Third',
          'last' => 'Person',
          'title' => 'Manager',
          'individualAssociationType' => 'va'
        }
      }
      education_benefits_claim.update!(parsed_form: form_data)
      conflicts = subject.proprietary_conflicts
      expect(conflicts.length).to eq(2)
    end
  end

  describe '#all_proprietary_conflicts_count' do
    it 'returns the number of all proprietary conflicts' do
      expect(subject.all_proprietary_conflicts_count).to eq(2)
    end

    it 'limits to maximum of 2' do
      form_data['allProprietaryProfitConflicts'] << {
        'certifyingOfficial' => {
          'first' => 'Third',
          'last' => 'Official',
          'title' => 'Manager'
        },
        'fileNumber' => '555555555',
        'enrollmentPeriod' => {
          'from' => '2021-01-01',
          'to' => '2021-12-31'
        }
      }
      education_benefits_claim.update!(parsed_form: form_data)
      expect(subject.all_proprietary_conflicts_count).to eq(2)
    end

    context 'when no conflicts exist' do
      before do
        form_data['allProprietaryProfitConflicts'] = []
        education_benefits_claim.update!(parsed_form: form_data)
      end

      it 'returns 0' do
        expect(subject.all_proprietary_conflicts_count).to eq(0)
      end
    end
  end

  describe '#all_proprietary_conflicts' do
    it 'returns the all proprietary conflicts array' do
      conflicts = subject.all_proprietary_conflicts
      expect(conflicts).to be_an(Array)
      expect(conflicts.length).to eq(2)
      expect(conflicts.first['certifyingOfficial']['first']).to eq('Alice')
    end

    it 'returns only first 2 conflicts' do
      form_data['allProprietaryProfitConflicts'] << {
        'certifyingOfficial' => {
          'first' => 'Third',
          'last' => 'Official',
          'title' => 'Manager'
        },
        'fileNumber' => '555555555',
        'enrollmentPeriod' => {
          'from' => '2021-01-01',
          'to' => '2021-12-31'
        }
      }
      education_benefits_claim.update!(parsed_form: form_data)
      conflicts = subject.all_proprietary_conflicts
      expect(conflicts.length).to eq(2)
    end
  end

  describe '#header_form_type' do
    it 'returns the correct header form type' do
      expect(subject.header_form_type).to eq('V1919')
    end
  end
end
