# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form214192, type: :model do
  let(:form_data) do
    {
      veteranInformation: {
        fullName: { first: 'John', middle: 'M', last: 'Doe' },
        ssn: '123456789',
        dateOfBirth: '1980-01-01'
      },
      employmentInformation: {
        employerName: 'Acme Corporation',
        employerAddress: {
          street: '456 Business Ave',
          city: 'Commerce City',
          state: 'CA',
          postalCode: '54321'
        },
        employerEmail: 'hr@acme.com',
        employerPhone: '555-987-6543',
        contactPerson: {
          name: 'Jane Smith',
          title: 'HR Manager'
        },
        typeOfWorkPerformed: 'Software Developer',
        beginningDateOfEmployment: '2015-01-15',
        endingDateOfEmployment: '2023-06-30',
        amountEarnedLast12MonthsOfEmployment: 75_000,
        timeLostLast12MonthsOfEmployment: '2 weeks',
        hoursWorkedDaily: 8,
        hoursWorkedWeekly: 40,
        concessions: 'Flexible hours, ergonomic desk, modified duties',
        terminationReason: 'Medical disability',
        dateLastWorked: '2023-06-30',
        lastPaymentDate: '2023-07-15',
        lastPaymentGrossAmount: 6250,
        lumpSumPaymentMade: false,
        grossAmountPaid: 0,
        datePaid: '2023-07-15'
      },
      militaryDutyStatus: {
        currentDutyStatus: 'Active Reserve',
        veteranDisabilitiesPreventMilitaryDuties: true
      },
      benefitEntitlementPayments: {
        sickRetirementOtherBenefits: false,
        typeOfBenefit: 'Retirement',
        grossMonthlyAmountOfBenefit: 1500,
        dateBenefitBegan: '2023-01-01',
        dateFirstPaymentIssued: '2023-02-01',
        dateBenefitWillStop: '2025-12-31',
        remarks: 'Additional information about benefits and payments'
      }
    }
  end

  describe 'validations' do
    it 'validates required fields' do
      claim = described_class.new(form: form_data.to_json)
      expect(claim).to be_valid
    end

    it 'requires veteran information' do
      form_data.delete(:veteranInformation)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('Veteran information is required')
    end

    it 'requires employment information' do
      form_data.delete(:employmentInformation)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('Employment information is required')
    end

    it 'requires either SSN or VA file number' do
      form_data[:veteranInformation].delete(:ssn)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('Either SSN or VA file number is required for veteran')
    end

    it 'accepts VA file number instead of SSN' do
      form_data[:veteranInformation].delete(:ssn)
      form_data[:veteranInformation][:vaFileNumber] = '123456789'
      claim = described_class.new(form: form_data.to_json)
      expect(claim).to be_valid
    end

    it 'requires veteran full name' do
      form_data[:veteranInformation].delete(:fullName)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('Veteran full name is required')
    end

    it 'requires veteran date of birth' do
      form_data[:veteranInformation].delete(:dateOfBirth)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('Veteran date of birth is required')
    end

    it 'requires employer name' do
      form_data[:employmentInformation].delete(:employerName)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('employerName is required')
    end

    it 'requires employer address' do
      form_data[:employmentInformation].delete(:employerAddress)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('employerAddress is required')
    end

    it 'requires employer email' do
      form_data[:employmentInformation].delete(:employerEmail)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('employerEmail is required')
    end

    it 'requires type of work performed' do
      form_data[:employmentInformation].delete(:typeOfWorkPerformed)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('typeOfWorkPerformed is required')
    end

    it 'requires beginning date of employment' do
      form_data[:employmentInformation].delete(:beginningDateOfEmployment)
      claim = described_class.new(form: form_data.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors[:form_data]).to include('beginningDateOfEmployment is required')
    end
  end

  describe '#send_confirmation_email' do
    it 'does not send email (MVP does not include email)' do
      claim = described_class.new(form: form_data.to_json)
      expect(VANotify::EmailJob).not_to receive(:perform_async)
      claim.send_confirmation_email
    end
  end

  describe '#business_line' do
    it 'returns CMP for compensation claims' do
      claim = described_class.new(form: form_data.to_json)
      expect(claim.business_line).to eq('CMP')
    end
  end

  describe '#document_type' do
    it 'returns 119 for employment information' do
      claim = described_class.new(form: form_data.to_json)
      expect(claim.document_type).to eq(119)
    end
  end

  describe '#regional_office' do
    it 'returns empty array' do
      claim = described_class.new(form: form_data.to_json)
      expect(claim.regional_office).to eq([])
    end
  end

  describe '#process_attachments!' do
    it 'queues Lighthouse submission job without attachments' do
      claim = described_class.create!(form: form_data.to_json)
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(claim.id)
      claim.process_attachments!
    end
  end

  describe '#attachment_keys' do
    it 'returns empty array (no attachments in MVP)' do
      claim = described_class.new(form: form_data.to_json)
      expect(claim.attachment_keys).to eq([])
    end
  end

  describe 'FORM constant' do
    it 'is set to 21-4192' do
      expect(described_class::FORM).to eq('21-4192')
    end
  end
end
