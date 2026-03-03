# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_10'

RSpec.describe SurvivorsBenefits::StructuredData::Section10 do
  describe '#build_section10' do
    it 'calls merge_care_expense_fields' do
      form = { 'careExpenses' => [] }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_care_expense_fields).with(form['careExpenses'])
      service.build_section10
    end

    it 'calls merge_medical_expense_fields' do
      form = { 'medicalExpenses' => [] }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_medical_expense_fields).with(form['medicalExpenses'])
      service.build_section10
    end

    it 'merges has reimbursement boolean fields' do
      form = { 'careExpenses' => [{}], 'medicalExpenses' => [{}] }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section10
      expect(service.fields).to include(
        'UNREIMBURSED_MED_EXPENSES_Y' => true,
        'UNREIMBURSED_MED_EXPENSES_N' => false
      )
    end
  end

  describe '#any_reimbursement?' do
    it 'returns true if there are any care expenses' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({ 'careExpenses' => [{}] })
      expect(service.any_reimbursement?).to be true
    end

    it 'returns true if there are any medical expenses' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({ 'medicalExpenses' => [{}] })
      expect(service.any_reimbursement?).to be true
    end

    it 'returns false if there are no care or medical expenses' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      expect(service.any_reimbursement?).to be false
    end
  end

  describe '#merge_care_expense_fields' do
    let(:care_expenses) do
      [
        {
          'careType' => 'IN_HOME_CARE_ATTENDANT',
          'recipient' => 'SURVIVING_SPOUSE',
          'provider' => 'Some provider',
          'careDateRange' => { 'from' => '2020-01-01' },
          'paymentAmount' => 200.45,
          'noCareEndDate' => true,
          'paymentFrequency' => 'MONTHLY',
          'hoursPerWeek' => 20,
          'ratePerHour' => 15
        },
        {
          'careType' => 'CARE_FACILITY',
          'recipient' => 'OTHER',
          'recipientName' => 'John Doe',
          'provider' => 'Some care facility',
          'careDateRange' => { 'from' => '2021-02-01', 'to' => '2021-02-15' },
          'paymentAmount' => 5000,
          'paymentFrequency' => 'ANNUALLY'
        }
      ]
    end

    it 'calls merge_care_type_fields for each care expense' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      expect(service).to receive(:merge_care_type_fields).with(1, care_expenses[0]['careType'])
      expect(service).to receive(:merge_care_type_fields).with(2, care_expenses[1]['careType'])
      service.merge_care_expense_fields(care_expenses)
    end

    it 'merges expected fields for each care expense' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_care_expense_fields(care_expenses)
      expect(service.fields).to include(
        'CB_PROVIDER_TYPE_INHOMECARE1' => true,
        'CB_PROVIDER_TYPE_CAREFACILITY1' => false,
        'CB_EXPENSES_PAID_SP1' => true,
        'CB_EXPENSES_PAID_OTHER1' => false,
        'NAME_OF_DEPENDENT1' => nil,
        'NAME_OF_PROVIDER1' => 'Some provider',
        'PMNT_RATE_INHOMECARE1' => '$15.00',
        'HRS_PER_WEEK1' => 20,
        'AMNT_YOU_PAY1' => '$200.45',
        'AMNT_YOU_PAY_1_THSNDS' => 0,
        'AMNT_YOU_PAY_1_HNDRDS' => 200,
        'AMNT_YOU_PAY_1_CENTS' => 45,
        'PROVIDER_START_DATE1' => '01/01/2020',
        'PROVIDER_END_DATE1' => nil,
        'CB_NO_END_DATE1' => true,
        'CB_PAYMENT_MONTHLY1' => true,
        'CB_PAYMENT_ANNUALLY1' => false,
        'CB_PROVIDER_TYPE_INHOMECARE2' => false,
        'CB_PROVIDER_TYPE_CAREFACILITY2' => true,
        'CB_EXPENSES_PAID_SP2' => false,
        'CB_EXPENSES_PAID_OTHER2' => true,
        'NAME_OF_DEPENDENT2' => 'John Doe',
        'NAME_OF_PROVIDER2' => 'Some care facility',
        'PMNT_RATE_INHOMECARE2' => nil,
        'HRS_PER_WEEK2' => nil,
        'AMNT_YOU_PAY_2' => '$5,000.00',
        'AMNT_YOU_PAY_2_THSNDS' => 5,
        'AMNT_YOU_PAY_2_HNDRDS' => 0,
        'AMNT_YOU_PAY_2_CENTS' => 0,
        'PROVIDER_START_DATE2' => '02/01/2021',
        'PROVIDER_END_DATE2' => '02/15/2021',
        'CB_NO_END_DATE2' => false,
        'CB_PAYMENT_MONTHLY2' => false,
        'CB_PAYMENT_ANNUALLY2' => true
      )
    end
  end

  describe '#merge_care_type_fields' do
    it 'merges expected fields for IN_HOME_CARE_ATTENDANT care type' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_care_type_fields(1, 'IN_HOME_CARE_ATTENDANT')
      expect(service.fields).to include(
        'CB_PROVIDER_TYPE_INHOMECARE1' => true,
        'CB_PROVIDER_TYPE_CAREFACILITY1' => false
      )
    end

    it 'merges expected fields for CARE_FACILITY care type' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_care_type_fields(1, 'CARE_FACILITY')
      expect(service.fields).to include(
        'CB_PROVIDER_TYPE_INHOMECARE1' => false,
        'CB_PROVIDER_TYPE_CAREFACILITY1' => true
      )
    end
  end

  describe '#care_expense_currency_keys' do
    it 'returns correct keys for expense_num 1' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      keys = service.care_expense_currency_keys(1)
      expect(keys).to eq(
        full: 'AMNT_YOU_PAY1',
        thousands: 'AMNT_YOU_PAY_1_THSNDS',
        hundreds: 'AMNT_YOU_PAY_1_HNDRDS',
        cents: 'AMNT_YOU_PAY_1_CENTS'
      )
    end

    it 'returns correct keys for expense_num 2' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      keys = service.care_expense_currency_keys(2)
      expect(keys).to eq(
        full: 'AMNT_YOU_PAY_2',
        thousands: 'AMNT_YOU_PAY_2_THSNDS',
        hundreds: 'AMNT_YOU_PAY_2_HNDRDS',
        cents: 'AMNT_YOU_PAY_2_CENTS'
      )
    end
  end

  describe '#merge_medical_expense_fields' do
    let(:medical_expenses) do
      [
        {
          'recipient' => 'SURVIVING_SPOUSE',
          'provider' => 'Some provider 2',
          'purpose' => 'Some purpose2',
          'paymentDate' => '2022-05-05',
          'paymentAmount' => 15_000,
          'paymentFrequency' => 'MONTHLY'
        },
        {
          'recipient' => 'CHILD',
          'childName' => 'Child name',
          'provider' => 'Some provider 1',
          'purpose' => 'Some purpose1',
          'paymentDate' => '2022-05-05',
          'paymentAmount' => 150,
          'paymentFrequency' => 'ANNUALLY'
        },
        {
          'recipient' => 'SURVIVING_SPOUSE',
          'provider' => 'Some provider 2',
          'purpose' => 'Some purpose2',
          'paymentDate' => '2022-05-05',
          'paymentAmount' => 1_000.25,
          'paymentFrequency' => 'MONTHLY'
        },
        {
          'recipient' => 'VETERAN',
          'provider' => 'Some provider 32',
          'purpose' => 'Some purpose32',
          'paymentDate' => '2022-05-05',
          'paymentAmount' => 150,
          'paymentFrequency' => 'ONE_TIME'
        }
      ]
    end

    it 'merges expected fields for each medical expense' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_medical_expense_fields(medical_expenses)
      expect(service.fields).to include(
        'MEDAMNT_YOU_PAY1' => '$15,000.00',
        'MEDAMNT_YOU_PAY1_THSNDS' => 15,
        'MEDAMNT_YOU_PAY1_HNDRDS' => 0,
        'MEDAMNT_YOU_PAY1_CENTS' => 0,
        'MED_EXPENSES_SP1' => true,
        'MED_EXPENSES_VET1' => false,
        'MED_EXPENSES_CHILD1' => false,
        'MED_EXPENSES_CHILDNAME1' => nil,
        'PAID_TO_PROVIDER1' => 'Some provider 2',
        'PAID_TO_PURPOSE1' => 'Some purpose2',
        'DATE_COSTS_INCURRED_START1' => '05/05/2022',
        'CB_PMNT_FREQUENCY_MONTHLY1' => true,
        'CB_PMNT_FREQUENCY_ANNUALLY1' => false,
        'CB_PMNT_FREQUENCY_ONETIME1' => false,
        'MEDAMNT_YOU_PAY2' => '$150.00',
        'MEDAMNT_YOU_PAY2_THSNDS' => 0,
        'MEDAMNT_YOU_PAY2_HNDRDS' => 150,
        'MEDAMNT_YOU_PAY2_CENTS' => 0,
        'MED_EXPENSES_SP2' => false,
        'MED_EXPENSES_VET2' => false,
        'MED_EXPENSES_CHILD2' => true,
        'MED_EXPENSES_CHILDNAME2' => 'Child name',
        'PAID_TO_PROVIDER2' => 'Some provider 1',
        'PAID_TO_PURPOSE2' => 'Some purpose1',
        'DATE_COSTS_INCURRED_START2' => '05/05/2022',
        'CB_PMNT_FREQUENCY_MONTHLY2' => false,
        'CB_PMNT_FREQUENCY_ANNUALLY2' => true,
        'CB_PMNT_FREQUENCY_ONETIME2' => false,
        'MEDAMNT_YOU_PAY3' => '$1,000.25',
        'MEDAMNT_YOU_PAY3_THSNDS' => 1,
        'MEDAMNT_YOU_PAY3_HNDRDS' => 0,
        'MEDAMNT_YOU_PAY3_CENTS' => 25,
        'MED_EXPENSES_SP3' => true,
        'MED_EXPENSES_VET3' => false,
        'MED_EXPENSES_CHILD3' => false,
        'MED_EXPENSES_CHILDNAME3' => nil,
        'PAID_TO_PROVIDER3' => 'Some provider 2',
        'PAID_TO_PURPOSE3' => 'Some purpose2',
        'DATE_COSTS_INCURRED_START3' => '05/05/2022',
        'CB_PMNT_FREQUENCY_MONTHLY3' => true,
        'CB_PMNT_FREQUENCY_ANNUALLY3' => false,
        'CB_PMNT_FREQUENCY_ONETIME3' => false,
        'MEDAMNT_YOU_PAY4' => '$150.00',
        'MEDAMNT_YOU_PAY4_THSNDS' => 0,
        'MEDAMNT_YOU_PAY4_HNDRDS' => 150,
        'MEDAMNT_YOU_PAY4_CENTS' => 0,
        'MED_EXPENSES_SP4' => false,
        'MED_EXPENSES_VET4' => true,
        'MED_EXPENSES_CHILD4' => false,
        'MED_EXPENSES_CHILDNAME4' => nil,
        'PAID_TO_PROVIDER4' => 'Some provider 32',
        'PAID_TO_PURPOSE4' => 'Some purpose32',
        'DATE_COSTS_INCURRED_START4' => '05/05/2022',
        'CB_PMNT_FREQUENCY_MONTHLY4' => false,
        'CB_PMNT_FREQUENCY_ANNUALLY4' => false,
        'CB_PMNT_FREQUENCY_ONETIME4' => true
      )
    end
  end

  describe '#medical_expense_currency_keys' do
    it 'returns correct keys' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      keys = service.medical_expense_currency_keys(2)
      expect(keys).to eq(
        full: 'MEDAMNT_YOU_PAY2',
        thousands: 'MEDAMNT_YOU_PAY2_THSNDS',
        hundreds: 'MEDAMNT_YOU_PAY2_HNDRDS',
        cents: 'MEDAMNT_YOU_PAY2_CENTS'
      )
    end
  end
end
