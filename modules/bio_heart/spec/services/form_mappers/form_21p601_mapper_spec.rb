# frozen_string_literal: true

require 'rails_helper'
require 'bio_heart_api/form_mappers/form_21p601_mapper'

RSpec.describe BioHeartApi::FormMappers::Form21p0601Mapper do
  let(:form_data) do
    # JSON sent from the FE gets converted to a hash with
    # snake_case keynames, so emulating that here:
    JSON.parse(
      Rails.root.join(
        'modules', 'bio_heart', 'spec', 'fixtures', 'form_21p601_complete.json'
      ).read
    ).to_h.deep_transform_keys(&:underscore)
  end

  describe '#call' do
    subject(:result) { described_class.new(form_data).call }

    it 'transforms form data to IBM MMS payload structure' do
      expect(result).to include(
        'VETERAN_FIRST_NAME' => 'Robert',
        'VETERAN_LAST_NAME' => 'Thompson',
        'FORM_TYPE' => 'StructuredData:21P-601'
      )
    end

    it 'produces expected complete payload structure' do
      # These keynames are those listed in the data dictionary from MMS
      expected_keys =
        %w[VETERAN_NAME
           VETERAN_FIRST_NAME
           VETERAN_MIDDLE_INITIAL
           VETERAN_LAST_NAME
           VETERAN_SSN
           VA_FILE_NUMBER
           DECEDENT_NAME
           DECEASED_DEATH_DATE
           CLAIMANT_NAME
           CLAIMANT_FIRST_NAME
           CLAIMANT_MIDDLE_INITIAL
           CLAIMANT_LAST_NAME
           CLAIMANT_SSN
           CLAIMANT_DOB
           CLAIMANT_ADDRESS_FULL_BLOCK
           CLAIMANT_ADDRESS_LINE1
           CLAIMANT_ADDRESS_LINE2
           CLAIMANT_ADDRESS_CITY
           CLAIMANT_ADDRESS_STATE
           CLAIMANT_ADDRESS_COUNTRY
           CLAIMANT_ADDRESS_ZIP5
           CLAIMANT_PHONE_NUMBER
           CLAIMANT_EMAIL
           CLAIMANT_RELATIONSHIP
           RELATIONSHIP_SURVIVING_SPOUSE
           RELATIONSHIP_CHILD
           RELATIONSHIP_PARENT
           RELATIONSHIP_NONE
           NAME_OF_RELATIVE_1
           NAME_OF_RELATIVE_2
           NAME_OF_RELATIVE_3
           NAME_OF_RELATIVE_4
           RELATION_RELATIVE_1
           RELATION_RELATIVE_2
           RELATION_RELATIVE_3
           RELATION_RELATIVE_4
           DOB_RELATIVE_1
           DOB_RELATIVE_2
           DOB_RELATIVE_3
           DOB_RELATIVE_4
           ADDRESS_RELEATIVE_1
           ADDRESS_RELEATIVE_2
           ADDRESS_RELEATIVE_3
           ADDRESS_RELEATIVE_4
           WAIVE_YES
           WAIVE_NO
           EXPENSE_PAID_TO_1
           EXPENSE_PAID_TO_2
           EXPENSE_PAID_TO_3
           EXPENSE_PAID_TO_4
           EXPENSE_PAID_FOR_1
           EXPENSE_PAID_FOR_2
           EXPENSE_PAID_FOR_3
           EXPENSE_PAID_FOR_4
           EXPENSE_AMT_1
           EXPENSE_AMT_2
           EXPENSE_AMT_3
           EXPENSE_AMT_4
           PAID_1
           UNPAID_1
           PAID_2
           UNPAID_2
           PAID_3
           UNPAID_3
           PAID_4
           UNPAID_4
           EXPENSE_PAID_BY_1
           EXPENSE_PAID_BY_2
           EXPENSE_PAID_BY_3
           EXPENSE_PAID_BY_4
           REIMBURSED_YES
           REIMBURSED_NO
           OTHER_DEBTS_YES
           OTHER_DEBTS_NO
           OTHER_DEBT_1
           OTHER_DEBT_2
           OTHER_DEBT_3
           OTHER_DEBT_4
           OTHER_DEBT_AMOUNT_1
           OTHER_DEBT_AMOUNT_2
           OTHER_DEBT_AMOUNT_3
           OTHER_DEBT_AMOUNT_4
           ESTATE_ADMIN_YES
           ESTATE_ADMIN_NO
           OTHER_DEBT_CREDITOR_1
           OTHER_DEBT_CREDITOR_ADDRESS_1
           OTHER_DEBT_CREDITOR_SIGN_1
           OTHER_DEBT_CREDITOR_TITLE_1
           OTHER_DEBT_CREDITOR_DATE_1
           OTHER_DEBT_CREDITOR_2
           OTHER_DEBT_CREDITOR_ADDRESS_2
           OTHER_DEBT_CREDITOR_SIGN_2
           OTHER_DEBT_CREDITOR_TITLE_2
           OTHER_DEBT_CREDITOR_DATE_2
           OTHER_DEBT_CREDITOR_3
           OTHER_DEBT_CREDITOR_ADDRESS_3
           OTHER_DEBT_CREDITOR_SIGN_3
           OTHER_DEBT_CREDITOR_TITLE_3
           OTHER_DEBT_CREDITOR_DATE_3
           CLAIMANT_SIGNATURE
           DATE_OF_CLAIMANT_SIGNATURE
           WITNESS_1_SIGNATURE
           WITNESS_1_NAME_ADDRESS
           WITNESS_2_SIGNATURE
           WITNESS_2_NAME_ADDRESS
           REMARKS
           FORM_TYPE]
      expect(result.keys).to match_array(expected_keys)
    end

    context 'with missing optional fields' do
      let(:minimal_data) do
        {
          'veteran' => { 'full_name' => { 'first' => 'John', 'last' => 'Doe' } },
          'claimant' => { 'full_name' => { 'first' => 'Jane', 'last' => 'Doe' } }
        }
      end

      it 'handles missing middle name gracefully' do
        result = described_class.new(minimal_data).call
        expect(result['VETERAN_MIDDLE_INITIAL']).to be_nil
      end

      it 'handles missing address' do
        result = described_class.new(minimal_data).call
        expect(result['CLAIMANT_ADDRESS_FULL_BLOCK']).to be_nil
      end
    end

    context 'with empty arrays' do
      before { form_data['expenses']['expenses_list'] = [] }

      it 'fills all expense slots with nil' do
        (1..4).each do |num|
          expect(result["EXPENSE_PAID_TO_#{num}"]).to be_nil
          expect(result["PAID_#{num}"]).to be(false)
        end
      end
    end

    context 'Box 14E - Waive Substitution' do
      context 'when wants to waive' do
        before { form_data['surviving_relatives']['wants_to_waive_substitution'] = true }

        it 'checks YES and unchecks NO' do
          expect(result['WAIVE_YES']).to be(true)
          expect(result['WAIVE_NO']).to be(false)
        end
      end

      context 'when does not want to waive' do
        before { form_data['surviving_relatives']['wants_to_waive_substitution'] = false }

        it 'checks NO and unchecks YES' do
          expect(result['WAIVE_YES']).to be(false)
          expect(result['WAIVE_NO']).to be(true)
        end
      end
    end

    context 'Box 14A-D - Surviving Relatives' do
      context 'with 2 relatives' do
        it 'maps first 2 slots and nils remaining slots' do
          expect(result['NAME_OF_RELATIVE_1']).to be_present
          expect(result['NAME_OF_RELATIVE_2']).to be_present
          expect(result['NAME_OF_RELATIVE_3']).to be_nil
          expect(result['NAME_OF_RELATIVE_4']).to be_nil
        end
      end

      context 'with more than 4 relatives' do
        before do
          form_data['surviving_relatives']['relatives'] =
            5.times.map { |i| { 'full_name' => { 'first' => "Person#{i}" } } }
        end

        it 'only maps first 4 relatives' do
          expect(result['NAME_OF_RELATIVE_4']).to be_present
          # Fifth relative should not create a slot
          expect(result['NAME_OF_RELATIVE_5']).to be_nil
        end
      end
    end
  end
end
