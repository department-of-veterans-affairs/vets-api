# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va221919'

describe PdfFill::Forms::Va221919 do
  subject { described_class.new(form_data) }

  let(:form_data) do
    {
      'institutionDetails' => {
        'institutionName' => 'Acme U',
        'institutionAddress' => { 'street' => '123 Main St' },
        'facilityCode' => '12345678'
      },
      'certifyingOfficial' => {
        'first' => 'Jane',
        'last' => 'Doe',
        'role' => { 'level' => 'director' }
      },
      'isProprietaryProfit' => true,
      'isProfitConflictOfInterest' => false,
      'proprietaryProfitConflicts' => [
        { 'affiliatedIndividuals' => { 'first' => 'Ann', 'last' => 'Smith',
                                       'individualAssociationType' => 'employee' } },
        { 'affiliatedIndividuals' => { 'first' => 'Bob', 'last' => 'Jones',
                                       'individualAssociationType' => 'owner' } },
        { 'affiliatedIndividuals' => { 'first' => 'Extra', 'last' => 'Person',
                                       'individualAssociationType' => 'other' } }
      ],
      'allProprietaryConflictOfInterest' => nil,
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
  end

  describe '#merge_fields' do
    it 'applies formatter transformations and returns a new hash' do
      result = subject.merge_fields

      expect(result).not_to be(form_data)

      expect(result['certifyingOfficial']['fullName']).to eq('Jane Doe')
      expect(result['certifyingOfficial']['role']['displayRole']).to eq('director')

      expect(result['isProprietaryProfit']).to eq('YES')
      expect(result['isProfitConflictOfInterest']).to eq('NO')
      expect(result['allProprietaryConflictOfInterest']).to eq('N/A')

      expect(result['proprietaryProfitConflicts0']).to eq(
        'employeeName' => 'Ann Smith',
        'association' => 'EMPLOYEE'
      )
      expect(result['proprietaryProfitConflicts1']).to eq(
        'employeeName' => 'Bob Jones',
        'association' => 'OWNER'
      )
      expect(result.key?('proprietaryProfitConflicts2')).to be(false)

      expect(result['allProprietaryProfitConflicts0']).to eq(
        'officialName' => 'Cathy Brown',
        'fileNumber' => 'FN-1',
        'enrollmentDateRange' => '2024-01-01',
        'enrollmentDateRangeEnd' => '2024-12-31'
      )
      expect(result['allProprietaryProfitConflicts1']).to eq(
        'officialName' => 'Dan White',
        'fileNumber' => 'FN-2',
        'enrollmentDateRange' => '2023-01-01',
        'enrollmentDateRangeEnd' => '2023-12-31'
      )
      expect(result.key?('allProprietaryProfitConflicts2')).to be(false)
    end

    it 'handles missing certifyingOfficial gracefully' do
      form_data.delete('certifyingOfficial')
      expect { subject.merge_fields }.not_to raise_error
    end

    it 'handles nil booleans and missing conflict arrays without error' do
      form_data['isProprietaryProfit'] = nil
      form_data['isProfitConflictOfInterest'] = nil
      form_data['allProprietaryConflictOfInterest'] = nil
      form_data.delete('proprietaryProfitConflicts')
      form_data.delete('allProprietaryProfitConflicts')

      result = subject.merge_fields
      expect(result['isProprietaryProfit']).to eq('N/A')
      expect(result['isProfitConflictOfInterest']).to eq('N/A')
      expect(result['allProprietaryConflictOfInterest']).to eq('N/A')
    end
  end
end
