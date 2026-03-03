# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/mappers/base_mapper'
require 'form_intake/mappers/vba_21p_601_mapper'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe FormIntake::Mappers::VBA21p601Mapper do
  let(:form_data) do
    # Form data is snake_cased by middleware before reaching mappers
    {
      'form_number' => '21P-601',
      'veteran' => {
        'full_name' => { 'first' => 'Robert', 'middle' => 'James', 'last' => 'Thompson' },
        'ssn' => { 'first3' => '123', 'middle2' => '45', 'last4' => '6789' },
        'va_file_number' => '987654321'
      },
      'beneficiary' => {
        'full_name' => { 'first' => 'Robert', 'middle' => 'James', 'last' => 'Thompson' },
        'date_of_death' => { 'month' => '06', 'day' => '15', 'year' => '2024' },
        'is_veteran' => true
      },
      'claimant' => {
        'full_name' => { 'first' => 'Sarah', 'middle' => 'Anne', 'last' => 'Thompson' },
        'ssn' => { 'first3' => '555', 'middle2' => '66', 'last4' => '7778' },
        'va_file_number' => '',
        'date_of_birth' => { 'month' => '03', 'day' => '22', 'year' => '1970' },
        'relationship_to_deceased' => 'spouse',
        'address' => {
          'street' => '456 Memorial Drive',
          'street2' => 'Apt 301',
          'city' => 'Richmond',
          'state' => 'VA',
          'country' => 'USA',
          'zip_code' => { 'first5' => '23220', 'last4' => '' }
        },
        'phone' => { 'area_code' => '804', 'prefix' => '555', 'line_number' => '1234' },
        'email' => 'sarah.thompson@email.com',
        'signature' => 'Sarah Anne Thompson',
        'signature_date' => { 'month' => '10', 'day' => '01', 'year' => '2025' }
      },
      'surviving_relatives' => {
        'has_spouse' => false,
        'has_children' => true,
        'has_parents' => false,
        'has_none' => false,
        'wants_to_waive_substitution' => false,
        'relatives' => [
          {
            'full_name' => { 'first' => 'Michael', 'middle' => 'Robert', 'last' => 'Thompson' },
            'relationship' => 'child',
            'date_of_birth' => { 'month' => '08', 'day' => '10', 'year' => '1995' },
            'address' => {
              'street' => '789 Oak Street',
              'city' => 'Arlington',
              'state' => 'VA',
              'country' => 'USA',
              'zip_code' => { 'first5' => '22201' }
            }
          },
          {
            'full_name' => { 'first' => 'Emily', 'last' => 'Thompson' },
            'relationship' => 'child',
            'date_of_birth' => { 'month' => '11', 'day' => '22', 'year' => '1998' },
            'address' => {
              'street' => '123 Pine Avenue',
              'city' => 'Alexandria',
              'state' => 'VA',
              'zip_code' => { 'first5' => '22314' }
            }
          }
        ]
      },
      'expenses' => {
        'expenses_list' => [
          {
            'provider' => 'Virginia Hospital Center',
            'expense_type' => 'Hospital care',
            'amount' => '15000',
            'is_paid' => true,
            'paid_by' => 'Sarah Thompson'
          },
          {
            'provider' => 'Dr. James Mitchell',
            'expense_type' => 'Physician services',
            'amount' => '2500.50',
            'is_paid' => false,
            'paid_by' => ''
          }
        ],
        'other_debts' => [
          {
            'debt_type' => 'Credit card debt',
            'debt_amount' => '3500'
          }
        ]
      },
      'remarks' => 'Additional information about the claim'
    }.to_json
  end

  let(:form_submission) { create(:form_submission, form_type: '21P-601', form_data:) }
  let(:benefits_intake_uuid) { 'uuid-123-456' }
  let(:mapper) { described_class.new(form_submission, benefits_intake_uuid) }

  describe '#to_gcio_payload' do
    let(:payload) { mapper.to_gcio_payload }

    it 'includes form type with StructuredData prefix' do
      expect(payload['FORM_TYPE']).to eq('StructuredData:21P-601')
    end

    it 'maps veteran name fields' do
      expect(payload['VETERAN_NAME']).to eq('Robert James Thompson')
      expect(payload['VETERAN_FIRST_NAME']).to eq('Robert')
      expect(payload['VETERAN_MIDDLE_INITIAL']).to eq('J')
      expect(payload['VETERAN_LAST_NAME']).to eq('Thompson')
      expect(payload['VETERAN_SSN']).to eq('123456789')
      expect(payload['VA_FILE_NUMBER']).to eq('987654321')
    end

    it 'maps deceased beneficiary name and date' do
      expect(payload['DECEDENT_NAME']).to eq('Robert James Thompson')
      expect(payload['DECEASED_DEATH_DATE']).to eq('06/15/2024')
    end

    it 'maps claimant name fields' do
      expect(payload['CLAIMANT_NAME']).to eq('Sarah Anne Thompson')
      expect(payload['CLAIMANT_FIRST_NAME']).to eq('Sarah')
      expect(payload['CLAIMANT_MIDDLE_INITIAL']).to eq('A')
      expect(payload['CLAIMANT_LAST_NAME']).to eq('Thompson')
    end

    it 'maps claimant identification and contact' do
      expect(payload['CLAIMANT_SSN']).to eq('555667778')
      expect(payload['CLAIMANT_DOB']).to eq('03/22/1970')
      expect(payload['CLAIMANT_PHONE_NUMBER']).to eq('8045551234')
      expect(payload['CLAIMANT_EMAIL']).to eq('sarah.thompson@email.com')
      expect(payload['CLAIMANT_RELATIONSHIP']).to eq('spouse')
    end

    it 'maps claimant address fields' do
      expect(payload['CLAIMANT_ADDRESS_FULL_BLOCK']).to eq('456 Memorial Drive, Apt 301, Richmond, VA, USA, 23220')
      expect(payload['CLAIMANT_ADDRESS_LINE1']).to eq('456 Memorial Drive')
      expect(payload['CLAIMANT_ADDRESS_LINE2']).to eq('Apt 301')
      expect(payload['CLAIMANT_ADDRESS_CITY']).to eq('Richmond')
      expect(payload['CLAIMANT_ADDRESS_STATE']).to eq('VA')
      expect(payload['CLAIMANT_ADDRESS_COUNTRY']).to eq('USA')
      expect(payload['CLAIMANT_ADDRESS_ZIP5']).to eq('23220')
    end

    it 'maps surviving relatives checkboxes' do
      expect(payload['RELATIONSHIP_SURVIVING_SPOUSE']).to be false
      expect(payload['RELATIONSHIP_CHILD']).to be true
      expect(payload['RELATIONSHIP_PARENT']).to be false
      expect(payload['RELATIONSHIP_NONE']).to be false
    end

    it 'maps waive substitution checkboxes' do
      expect(payload['WAIVE_YES']).to be false
      expect(payload['WAIVE_NO']).to be true
    end

    it 'maps first relative (numbered fields)' do
      expect(payload['NAME_OF_RELATIVE_1']).to eq('Michael Robert Thompson')
      expect(payload['RELATION_RELATIVE_1']).to eq('child')
      expect(payload['DOB_RELATIVE_1']).to eq('08/10/1995')
      expect(payload['ADDRESS_RELEATIVE_1']).to eq('789 Oak Street, Arlington, VA, USA, 22201')
    end

    it 'maps second relative' do
      expect(payload['NAME_OF_RELATIVE_2']).to eq('Emily Thompson')
      expect(payload['RELATION_RELATIVE_2']).to eq('child')
      expect(payload['DOB_RELATIVE_2']).to eq('11/22/1998')
    end

    it 'fills empty relative slots with nil' do
      expect(payload['NAME_OF_RELATIVE_3']).to be_nil
      expect(payload['NAME_OF_RELATIVE_4']).to be_nil
    end

    it 'maps first expense' do
      expect(payload['EXPENSE_PAID_TO_1']).to eq('Virginia Hospital Center')
      expect(payload['EXPENSE_PAID_FOR_1']).to eq('Hospital care')
      expect(payload['EXPENSE_AMT_1']).to eq('15000.00')
      expect(payload['PAID_1']).to be true
      expect(payload['UNPAID_1']).to be false
      expect(payload['EXPENSE_PAID_BY_1']).to eq('Sarah Thompson')
    end

    it 'maps second expense' do
      expect(payload['EXPENSE_PAID_TO_2']).to eq('Dr. James Mitchell')
      expect(payload['EXPENSE_AMT_2']).to eq('2500.50')
      expect(payload['PAID_2']).to be false
      expect(payload['UNPAID_2']).to be true
    end

    it 'fills empty expense slots' do
      expect(payload['EXPENSE_PAID_TO_3']).to be_nil
      expect(payload['EXPENSE_PAID_TO_4']).to be_nil
      expect(payload['PAID_3']).to be false
      expect(payload['UNPAID_3']).to be false
    end

    it 'maps other debts checkboxes' do
      expect(payload['OTHER_DEBTS_YES']).to be true
      expect(payload['OTHER_DEBTS_NO']).to be false
    end

    it 'maps first other debt' do
      expect(payload['OTHER_DEBT_1']).to eq('Credit card debt')
      expect(payload['OTHER_DEBT_AMOUNT_1']).to eq('3500.00')
    end

    it 'fills empty debt slots' do
      expect(payload['OTHER_DEBT_2']).to be_nil
      expect(payload['OTHER_DEBT_3']).to be_nil
      expect(payload['OTHER_DEBT_4']).to be_nil
    end

    it 'maps signature fields' do
      expect(payload['CLAIMANT_SIGNATURE']).to eq('Sarah Anne Thompson')
      expect(payload['DATE_OF_CLAIMANT_SIGNATURE']).to eq('10/01/2025')
    end

    it 'includes remarks' do
      expect(payload['REMARKS']).to eq('Additional information about the claim')
    end

    it 'includes required nil fields for unsupported features' do
      # MMS requires these keys even though frontend doesn't provide them
      expect(payload).to have_key('ESTATE_ADMIN_YES')
      expect(payload).to have_key('ESTATE_ADMIN_NO')
      expect(payload).to have_key('OTHER_DEBT_CREDITOR_1')
      expect(payload).to have_key('WITNESS_1_SIGNATURE')
      expect(payload).to have_key('WITNESS_2_SIGNATURE')

      # All should be nil
      expect(payload['ESTATE_ADMIN_YES']).to be_nil
      expect(payload['WITNESS_1_SIGNATURE']).to be_nil
    end

    context 'with no expenses' do
      let(:no_expenses_data) do
        data = JSON.parse(form_data)
        data.delete('expenses')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-601', form_data: no_expenses_data) }

      it 'fills all expense slots with nil/false' do
        expect(payload['EXPENSE_PAID_TO_1']).to be_nil
        expect(payload['PAID_1']).to be false
        expect(payload['OTHER_DEBTS_YES']).to be false
        expect(payload['OTHER_DEBTS_NO']).to be true
      end
    end

    context 'with 5 relatives (more than 4)' do
      let(:many_relatives_data) do
        data = JSON.parse(form_data)
        data['surviving_relatives']['relatives'] = [
          { 'full_name' => { 'first' => 'Person1', 'last' => 'Rel' }, 'relationship' => 'child' },
          { 'full_name' => { 'first' => 'Person2', 'last' => 'Rel' }, 'relationship' => 'child' },
          { 'full_name' => { 'first' => 'Person3', 'last' => 'Rel' }, 'relationship' => 'child' },
          { 'full_name' => { 'first' => 'Person4', 'last' => 'Rel' }, 'relationship' => 'child' },
          { 'full_name' => { 'first' => 'Person5', 'last' => 'Rel' }, 'relationship' => 'child' }
        ]
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-601', form_data: many_relatives_data) }

      it 'only includes first 4 relatives' do
        expect(payload['NAME_OF_RELATIVE_1']).to eq('Person1 Rel')
        expect(payload['NAME_OF_RELATIVE_2']).to eq('Person2 Rel')
        expect(payload['NAME_OF_RELATIVE_3']).to eq('Person3 Rel')
        expect(payload['NAME_OF_RELATIVE_4']).to eq('Person4 Rel')
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
