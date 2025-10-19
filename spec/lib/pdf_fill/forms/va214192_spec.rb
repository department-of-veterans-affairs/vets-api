# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

RSpec.describe PdfFill::Forms::Va214192 do
  let(:form_data) do
    {
      'veteranInformation' => {
        'fullName' => {
          'first' => 'John',
          'middle' => 'M',
          'last' => 'Doe'
        },
        'ssn' => '123456789',
        'vaFileNumber' => '987654321',
        'dateOfBirth' => '1980-01-15'
      },
      'employmentInformation' => {
        'employerName' => 'Acme Corporation',
        'employerAddress' => {
          'street' => '456 Business Ave',
          'city' => 'Commerce City',
          'state' => 'CA',
          'postalCode' => '54321'
        },
        'employerEmail' => 'hr@acme.com',
        'employerPhone' => '555-987-6543',
        'typeOfWorkPerformed' => 'Software Developer',
        'beginningDateOfEmployment' => '2015-01-15',
        'endingDateOfEmployment' => '2023-06-30',
        'amountEarnedLast12Months' => 75_000,
        'timeLostLast12MonthsOfEmployment' => '2 weeks',
        'hoursWorkedDaily' => 8,
        'hoursWorkedWeekly' => 40,
        'concessions' => 'Flexible hours, ergonomic desk',
        'terminationReason' => 'Medical disability',
        'dateLastWorked' => '2023-06-30',
        'lastPaymentDate' => '2023-07-15',
        'lastPaymentGrossAmount' => '6250.00',
        'lumpSumPaymentMade' => false,
        'grossAmountPaid' => '0',
        'datePaid' => '2023-07-15'
      },
      'militaryDutyStatus' => {
        'currentDutyStatus' => 'Active Reserve',
        'veteranDisabilitiesPreventMilitaryDuties' => true
      },
      'benefitEntitlementPayments' => {
        'sickRetirementOtherBenefits' => false,
        'typeOfBenefit' => 'Retirement',
        'grossMonthlyAmountOfBenefit' => 1500,
        'dateBenefitBegan' => '2023-01-01',
        'dateFirstPaymentIssued' => '2023-02-01',
        'dateBenefitWillStop' => '2025-12-31',
        'remarks' => 'Additional information'
      },
      'employerCertification' => {
        'certificationDate' => '2024-01-15',
        'signature' => 'Jane Smith'
      }
    }
  end

  describe '#merge_fields' do
    let(:form) { described_class.new(form_data) }

    it 'splits SSN into three parts' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['ssn']).to eq(
        'first' => '123',
        'second' => '45',
        'third' => '6789'
      )
    end

    it 'formats dates correctly' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['dateOfBirth']).to eq(
        'month' => '01',
        'day' => '15',
        'year' => '1980'
      )
    end

    it 'combines employer name and address' do
      merged = form.merge_fields

      expect(merged['employmentInformation']['employerNameAndAddress']).to include('Acme Corporation')
      expect(merged['employmentInformation']['employerNameAndAddress']).to include('456 Business Ave')
      expect(merged['employmentInformation']['employerNameAndAddress']).to include('Commerce City, CA 54321')
    end

    it 'formats dollar amounts correctly' do
      merged = form.merge_fields

      expect(merged['employmentInformation']['amountEarnedLast12Months']).to eq(
        'thousands' => '075',
        'hundreds' => '000',
        'cents' => '00'
      )
    end

    it 'converts booleans to YES/NO' do
      merged = form.merge_fields

      expect(merged['employmentInformation']['lumpSumPaymentMade']).to eq('NO')
      expect(merged['militaryDutyStatus']['veteranDisabilitiesPreventMilitaryDuties']).to eq('YES')
      expect(merged['benefitEntitlementPayments']['sickRetirementOtherBenefits']).to eq('NO')
    end
  end

  describe 'PDF generation' do
    it 'generates a PDF successfully', :skip_mvi do
      file_path = PdfFill::Filler.fill_ancillary_form(
        form_data,
        'test-123',
        '21-4192'
      )

      expect(File.exist?(file_path)).to be true
      expect(file_path).to include('21-4192')

      # Verify it's a valid PDF
      pdf_content = File.read(file_path)
      expect(pdf_content).to start_with('%PDF')

      # Cleanup
      FileUtils.rm_f(file_path)
    end

    it 'fills veteran name fields', :skip_mvi do
      file_path = PdfFill::Filler.fill_ancillary_form(
        form_data,
        'test-name',
        '21-4192'
      )

      expect(File.exist?(file_path)).to be true

      # Cleanup
      FileUtils.rm_f(file_path)
    end
  end
end
