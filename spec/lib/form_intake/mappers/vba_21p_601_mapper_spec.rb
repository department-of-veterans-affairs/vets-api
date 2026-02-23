# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/mappers/base_mapper'
require 'form_intake/mappers/vba_21p_601_mapper'

RSpec.describe FormIntake::Mappers::VBA21p601Mapper do
  let(:form_data) do
    {
      'formNumber' => '21P-601',
      'veteran' => {
        'fullName' => { 'first' => 'Robert', 'middle' => 'James', 'last' => 'Thompson' },
        'ssn' => { 'first3' => '123', 'middle2' => '45', 'last4' => '6789' },
        'vaFileNumber' => '987654321'
      },
      'beneficiary' => {
        'fullName' => { 'first' => 'Robert', 'middle' => 'James', 'last' => 'Thompson' },
        'dateOfDeath' => { 'month' => '06', 'day' => '15', 'year' => '2024' },
        'isVeteran' => true
      },
      'claimant' => {
        'fullName' => { 'first' => 'Sarah', 'middle' => 'Anne', 'last' => 'Thompson' },
        'ssn' => { 'first3' => '555', 'middle2' => '66', 'last4' => '7778' },
        'vaFileNumber' => '',
        'dateOfBirth' => { 'month' => '03', 'day' => '22', 'year' => '1970' },
        'relationshipToDeceased' => 'spouse',
        'address' => {
          'street' => '456 Memorial Drive',
          'street2' => 'Apt 301',
          'city' => 'Richmond',
          'state' => 'VA',
          'country' => 'USA',
          'zipCode' => { 'first5' => '23220', 'last4' => '' }
        },
        'phone' => { 'areaCode' => '804', 'prefix' => '555', 'lineNumber' => '1234' },
        'email' => 'sarah.thompson@email.com',
        'signature' => 'Sarah Anne Thompson',
        'signatureDate' => { 'month' => '10', 'day' => '01', 'year' => '2025' }
      },
      'survivingRelatives' => {
        'hasSpouse' => false,
        'hasChildren' => true,
        'hasParents' => false,
        'hasNone' => false,
        'wantsToWaiveSubstitution' => false,
        'relatives' => [
          {
            'fullName' => { 'first' => 'Michael', 'middle' => 'Robert', 'last' => 'Thompson' },
            'relationship' => 'child',
            'dateOfBirth' => { 'month' => '08', 'day' => '10', 'year' => '1995' },
            'address' => {
              'street' => '789 Oak Street',
              'city' => 'Arlington',
              'state' => 'VA',
              'country' => 'USA',
              'zipCode' => { 'first5' => '22201' }
            }
          }
        ]
      },
      'expenses' => {
        'expensesList' => [
          {
            'provider' => 'Virginia Hospital Center',
            'expenseType' => 'Hospital care',
            'amount' => '15000',
            'isPaid' => true,
            'paidBy' => 'Sarah Thompson'
          }
        ],
        'otherDebts' => [
          {
            'debtType' => 'Credit card debt',
            'debtAmount' => '3500'
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

    it 'includes form metadata' do
      expect(payload[:form_number]).to eq('21P-601')
      expect(payload[:benefits_intake_uuid]).to eq('uuid-123-456')
      expect(payload[:submission_id]).to eq(form_submission.id)
      expect(payload[:submitted_at]).to be_present
    end

    it 'maps veteran information' do
      expect(payload[:veteran][:first_name]).to eq('Robert')
      expect(payload[:veteran][:middle_name]).to eq('James')
      expect(payload[:veteran][:last_name]).to eq('Thompson')
      expect(payload[:veteran][:ssn]).to eq('123456789')
      expect(payload[:veteran][:va_file_number]).to eq('987654321')
    end

    it 'maps beneficiary information' do
      expect(payload[:beneficiary][:first_name]).to eq('Robert')
      expect(payload[:beneficiary][:middle_name]).to eq('James')
      expect(payload[:beneficiary][:last_name]).to eq('Thompson')
      expect(payload[:beneficiary][:date_of_death]).to eq('06/15/2024')
      expect(payload[:beneficiary][:is_veteran]).to be true
    end

    it 'maps claimant information' do
      expect(payload[:claimant][:first_name]).to eq('Sarah')
      expect(payload[:claimant][:middle_name]).to eq('Anne')
      expect(payload[:claimant][:last_name]).to eq('Thompson')
      expect(payload[:claimant][:ssn]).to eq('555667778')
      expect(payload[:claimant][:date_of_birth]).to eq('03/22/1970')
      expect(payload[:claimant][:relationship_to_deceased]).to eq('spouse')
      expect(payload[:claimant][:email]).to eq('sarah.thompson@email.com')
      expect(payload[:claimant][:phone]).to eq('8045551234')
      expect(payload[:claimant][:signature]).to eq('Sarah Anne Thompson')
      expect(payload[:claimant][:signature_date]).to eq('10/01/2025')
    end

    it 'maps claimant address as flattened string' do
      expect(payload[:claimant][:address]).to eq('456 Memorial Drive Apt 301 Richmond VA 23220 USA')
    end

    it 'does not include empty va_file_number for claimant' do
      expect(payload[:claimant]).not_to have_key(:va_file_number)
    end

    it 'maps surviving relatives' do
      expect(payload[:surviving_relatives][:has_spouse]).to be false
      expect(payload[:surviving_relatives][:has_children]).to be true
      expect(payload[:surviving_relatives][:has_parents]).to be false
      expect(payload[:surviving_relatives][:has_none]).to be false
      expect(payload[:surviving_relatives][:wants_to_waive_substitution]).to be false
    end

    it 'maps individual relatives' do
      relative = payload[:surviving_relatives][:relatives].first
      expect(relative[:first_name]).to eq('Michael')
      expect(relative[:middle_name]).to eq('Robert')
      expect(relative[:last_name]).to eq('Thompson')
      expect(relative[:relationship]).to eq('child')
      expect(relative[:date_of_birth]).to eq('08/10/1995')
      expect(relative[:address]).to eq('789 Oak Street Arlington VA 22201 USA')
    end

    it 'maps expenses list' do
      expense = payload[:expenses][:expenses_list].first
      expect(expense[:provider]).to eq('Virginia Hospital Center')
      expect(expense[:expense_type]).to eq('Hospital care')
      expect(expense[:amount]).to eq('15000')
      expect(expense[:is_paid]).to be true
      expect(expense[:paid_by]).to eq('Sarah Thompson')
    end

    it 'maps other debts' do
      debt = payload[:expenses][:other_debts].first
      expect(debt[:debt_type]).to eq('Credit card debt')
      expect(debt[:debt_amount]).to eq('3500')
    end

    it 'includes remarks' do
      expect(payload[:remarks]).to eq('Additional information about the claim')
    end

    context 'with minimal data' do
      let(:minimal_form_data) do
        {
          'formNumber' => '21P-601',
          'veteran' => {
            'fullName' => { 'first' => 'John', 'last' => 'Doe' }
          },
          'beneficiary' => {
            'fullName' => { 'first' => 'John', 'last' => 'Doe' }
          },
          'claimant' => {
            'fullName' => { 'first' => 'Jane', 'last' => 'Doe' },
            'relationshipToDeceased' => 'spouse'
          }
        }.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-601', form_data: minimal_form_data) }

      it 'handles missing optional fields gracefully' do
        expect { payload }.not_to raise_error
        expect(payload[:veteran][:first_name]).to eq('John')
        expect(payload[:veteran][:middle_name]).to be_nil
        expect(payload[:claimant]).not_to have_key(:ssn)
        expect(payload[:claimant]).not_to have_key(:phone)
        expect(payload).not_to have_key(:surviving_relatives)
        expect(payload).not_to have_key(:expenses)
      end
    end

    context 'with missing relatives array' do
      let(:form_data_no_relatives) do
        data = JSON.parse(form_data)
        data['survivingRelatives'].delete('relatives')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-601', form_data: form_data_no_relatives) }

      it 'does not include relatives array' do
        expect(payload[:surviving_relatives]).not_to have_key(:relatives)
      end
    end

    context 'with empty expenses' do
      let(:form_data_no_expenses) do
        data = JSON.parse(form_data)
        data.delete('expenses')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-601', form_data: form_data_no_expenses) }

      it 'does not include expenses key' do
        expect(payload).not_to have_key(:expenses)
      end
    end
  end
end

