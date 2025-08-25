# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/formatters/va221919'

describe PdfFill::Forms::Formatters::Va221919 do
  describe '.process_certifying_official' do
    it 'builds fullName when first and last are present' do
      data = { 'certifyingOfficial' => {
        'first' => 'Jane',
        'last' => 'Doe',
        'role' => { 'level' => 'director' }
      } }
      described_class.process_certifying_official(data)
      expect(data['certifyingOfficial']['fullName']).to eq('Jane Doe')
      expect(data['certifyingOfficial']['role']['displayRole']).to eq('director')
    end

    it 'uses role.other when level is other' do
      data = { 'certifyingOfficial' => { 'first' => 'A', 'last' => 'B',
                                         'role' => { 'level' => 'other', 'other' => 'Dean' } } }
      described_class.process_certifying_official(data)
      expect(data['certifyingOfficial']['role']['displayRole']).to eq('Dean')
    end

    it 'returns early when certifyingOfficial missing' do
      data = {}
      expect { described_class.process_certifying_official(data) }.not_to raise_error
    end

    it 'does nothing to displayRole when role missing' do
      data = { 'certifyingOfficial' => { 'first' => 'A', 'last' => 'B' } }
      described_class.process_certifying_official(data)
      expect(data['certifyingOfficial']['role']).to be_nil
    end
  end

  describe '.convert_boolean_fields' do
    it 'maps boolean and nil values to YES/NO/N/A' do
      data = {
        'isProprietaryProfit' => true,
        'isProfitConflictOfInterest' => false,
        'allProprietaryConflictOfInterest' => nil
      }
      described_class.convert_boolean_fields(data)
      expect(data['isProprietaryProfit']).to eq('YES')
      expect(data['isProfitConflictOfInterest']).to eq('NO')
      expect(data['allProprietaryConflictOfInterest']).to eq('N/A')
    end
  end

  describe '.process_proprietary_conflicts' do
    it 'extracts the first two conflicts into indexed keys' do
      data = {
        'proprietaryProfitConflicts' => [
          { 'affiliatedIndividuals' => { 'first' => 'Ann', 'last' => 'Smith',
                                         'individualAssociationType' => 'employee' } },
          { 'affiliatedIndividuals' => { 'first' => 'Bob', 'last' => 'Jones',
                                         'individualAssociationType' => 'owner' } },
          { 'affiliatedIndividuals' => { 'first' => 'Extra', 'last' => 'Person',
                                         'individualAssociationType' => 'other' } }
        ]
      }
      described_class.process_proprietary_conflicts(data)
      expect(data['proprietaryProfitConflicts0']).to eq(
        'employeeName' => 'Ann Smith', 'association' => 'EMPLOYEE'
      )
      expect(data['proprietaryProfitConflicts1']).to eq(
        'employeeName' => 'Bob Jones', 'association' => 'OWNER'
      )
      expect(data.key?('proprietaryProfitConflicts2')).to be(false)
    end

    it 'is a no-op when proprietaryProfitConflicts missing' do
      data = {}
      expect { described_class.process_proprietary_conflicts(data) }.not_to raise_error
    end
  end

  describe '.process_all_proprietary_conflicts' do
    it 'extracts the first two conflicts and maps nested fields' do
      data = {
        'allProprietaryProfitConflicts' => [
          {
            'certifyingOfficial' => { 'first' => 'Cathy', 'last' => 'Brown' },
            'fileNumber' => 'FN-1',
            'enrollmentPeriod' => { 'from' => '2024-01-01', 'to' => '2024-12-31' }
          },
          {
            'certifyingOfficial' => { 'first' => 'Dan', 'last' => 'White' },
            'fileNumber' => 'FN-2',
            'enrollmentPeriod' => { 'from' => '2023-01-01', 'to' => '2023-12-31' }
          },
          {
            'certifyingOfficial' => { 'first' => 'Extra', 'last' => 'Official' },
            'fileNumber' => 'FN-3',
            'enrollmentPeriod' => { 'from' => '2022-01-01', 'to' => '2022-12-31' }
          }
        ]
      }
      described_class.process_all_proprietary_conflicts(data)
      expect(data['allProprietaryProfitConflicts0']).to eq(
        'officialName' => 'Cathy Brown',
        'fileNumber' => 'FN-1',
        'enrollmentDateRange' => '2024-01-01',
        'enrollmentDateRangeEnd' => '2024-12-31'
      )
      expect(data['allProprietaryProfitConflicts1']).to eq(
        'officialName' => 'Dan White',
        'fileNumber' => 'FN-2',
        'enrollmentDateRange' => '2023-01-01',
        'enrollmentDateRangeEnd' => '2023-12-31'
      )
      expect(data.key?('allProprietaryProfitConflicts2')).to be(false)
    end

    it 'is a no-op when allProprietaryProfitConflicts missing' do
      data = {}
      expect { described_class.process_all_proprietary_conflicts(data) }.not_to raise_error
    end
  end

  describe '.convert_boolean_to_yes_no' do
    it 'returns YES/NO for true/false and N/A for nil' do
      expect(described_class.convert_boolean_to_yes_no(true)).to eq('YES')
      expect(described_class.convert_boolean_to_yes_no(false)).to eq('NO')
      expect(described_class.convert_boolean_to_yes_no(nil)).to eq('N/A')
    end
  end
end
