# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va221919'

describe PdfFill::Forms::Va221919 do
  let(:form_data) do
    JSON.parse(
      Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1919', 'minimal.json').read
    )
  end

  let(:form_class) do
    described_class.new(form_data)
  end

  describe '#merge_fields' do
    subject(:merged_fields) { form_class.merge_fields }

    it 'merges certifying official name correctly' do
      expect(merged_fields['certifyingOfficial']['fullName']).to eq('John Doe')
    end

    it 'sets display role correctly for standard role' do
      expect(merged_fields['certifyingOfficial']['role']['displayRole']).to eq('certifying official')
    end

    it 'converts boolean fields to YES/NO format' do
      expect(merged_fields['isProprietaryProfit']).to eq('YES')
      expect(merged_fields['isProfitConflictOfInterest']).to eq('YES')
      expect(merged_fields['allProprietaryConflictOfInterest']).to eq('YES')
    end

    it 'processes proprietary profit conflicts correctly' do
      expect(merged_fields['proprietaryProfitConflicts0']['employeeName']).to eq('Jane Smith')
      expect(merged_fields['proprietaryProfitConflicts0']['association']).to eq('VA')
      expect(merged_fields['proprietaryProfitConflicts1']['employeeName']).to eq('Bob Johnson')
      expect(merged_fields['proprietaryProfitConflicts1']['association']).to eq('SAA')
    end

    it 'processes all proprietary profit conflicts correctly' do
      expect(merged_fields['allProprietaryProfitConflicts0']['officialName']).to eq('Alice Williams')
      expect(merged_fields['allProprietaryProfitConflicts0']['fileNumber']).to eq('123456789')
      expect(merged_fields['allProprietaryProfitConflicts0']['enrollmentDateRange']).to eq('2023-01-01')
      expect(merged_fields['allProprietaryProfitConflicts0']['enrollmentDateRangeEnd']).to eq('2023-12-31')
    end

    it 'limits proprietary conflicts to maximum of 2' do
      form_data_with_many_conflicts = form_data.dup
      form_data_with_many_conflicts['proprietaryProfitConflicts'] = [
        form_data['proprietaryProfitConflicts'][0],
        form_data['proprietaryProfitConflicts'][1],
        {
          'affiliatedIndividuals' => {
            'first' => 'Third',
            'last' => 'Person',
            'title' => 'Manager',
            'individualAssociationType' => 'va'
          }
        }
      ]

      form_class_many = described_class.new(form_data_with_many_conflicts)
      merged = form_class_many.merge_fields

      expect(merged['proprietaryProfitConflicts0']).to be_present
      expect(merged['proprietaryProfitConflicts1']).to be_present
      expect(merged['proprietaryProfitConflicts2']).to be_nil
    end

    it 'limits all proprietary conflicts to maximum of 2' do
      form_data_with_many_conflicts = form_data.dup
      form_data_with_many_conflicts['allProprietaryProfitConflicts'] = [
        form_data['allProprietaryProfitConflicts'][0],
        form_data['allProprietaryProfitConflicts'][1],
        {
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
      ]

      form_class_many = described_class.new(form_data_with_many_conflicts)
      merged = form_class_many.merge_fields

      expect(merged['allProprietaryProfitConflicts0']).to be_present
      expect(merged['allProprietaryProfitConflicts1']).to be_present
      expect(merged['allProprietaryProfitConflicts2']).to be_nil
    end

    context 'when role is other' do
      let(:form_data_with_other_role) do
        data = form_data.dup
        data['certifyingOfficial']['role'] = {
          'level' => 'other',
          'other' => 'Custom Role'
        }
        data
      end

      let(:form_class_other) { described_class.new(form_data_with_other_role) }

      it 'uses the other field value for display role' do
        merged = form_class_other.merge_fields
        expect(merged['certifyingOfficial']['role']['displayRole']).to eq('Custom Role')
      end
    end

    context 'when boolean fields are false' do
      let(:form_data_false) do
        data = form_data.dup
        data['isProprietaryProfit'] = false
        data['isProfitConflictOfInterest'] = false
        data['allProprietaryConflictOfInterest'] = false
        data
      end

      let(:form_class_false) { described_class.new(form_data_false) }

      it 'converts false values to NO' do
        merged = form_class_false.merge_fields
        expect(merged['isProprietaryProfit']).to eq('NO')
        expect(merged['isProfitConflictOfInterest']).to eq('NO')
        expect(merged['allProprietaryConflictOfInterest']).to eq('NO')
      end
    end

    context 'when boolean fields are nil' do
      let(:form_data_nil) do
        data = form_data.dup
        data['isProprietaryProfit'] = nil
        data['isProfitConflictOfInterest'] = nil
        data['allProprietaryConflictOfInterest'] = nil
        data
      end

      let(:form_class_nil) { described_class.new(form_data_nil) }

      it 'converts nil values to N/A' do
        merged = form_class_nil.merge_fields
        expect(merged['isProprietaryProfit']).to eq('N/A')
        expect(merged['isProfitConflictOfInterest']).to eq('N/A')
        expect(merged['allProprietaryConflictOfInterest']).to eq('N/A')
      end
    end
  end
end
