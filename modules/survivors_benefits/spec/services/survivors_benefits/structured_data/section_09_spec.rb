# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_09'

RSpec.describe SurvivorsBenefits::StructuredData::Section09 do
  describe '#build_section9' do
    it 'calls merge_income_fields' do
      form = { 'incomeEntries' => [] }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_income_fields).with(form['incomeEntries'])
      service.build_section9
    end

    it 'merges expected fields' do
      form = {
        'incomeEntries' => [],
        'landMarketable' => true,
        'transferredAssets' => false,
        'homeOwnership' => true,
        'homeAcreageMoreThanTwo' => false,
        'moreThanFourIncomeSources' => true,
        'otherIncome' => false,
        'totalNetWorth' => false,
        'netWorthEstimation' => 50_000.25,
        'homeAcreageValue' => 100_000
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section9
      expect(service.fields).to include(
        'MARKETABLE_LAND_2ACR_Y' => true,
        'MARKETABLE_LAND_2ACR_N' => false,
        'TRANSFER_ASSETS_LAST3Y_Y' => false,
        'TRANSFER_ASSETS_LAST3Y_N' => true,
        'OWN_PRIMARY_RESIDENCE_Y' => true,
        'OWN_PRIMARY_RESIDENCE_N' => false,
        'RESLOT_OVER_2ACR_Y' => false,
        'RESLOT_OVER_2ACR_N' => true,
        'MORETHAN4_INCSOURCE_Y' => true,
        'MORETHAN4_INCSOURCE_N' => false,
        'PREV_YEAR_OTHER_INCOME_YES' => false,
        'PREV_YEAR_OTHER_INCOME_NO' => true,
        'ASSETS_OVER_25K_Y' => false,
        'ASSETS_OVER_25K_N' => true,
        'AMNT_ESTIMATE_ASSETS' => '$50,000.25',
        'AMNT_VALUE_OF_LOT' => '$100,000.00'
      )
    end
  end

  describe '#merge_income_fields' do
    let(:income_types) do
      {
        'SOCIAL_SECURITY' => 'SS',
        'PENSION_RETIREMENT' => 'PENSION',
        'CIVIL_SERVICE' => 'CIVIL',
        'INTEREST_DIVIDENDS' => 'INTEREST',
        'OTHER' => 'OTHER'
      }
    end

    it 'merges expected fields for all income types' do
      income_types.each_key.with_index do |key, index|
        income_multiplier = index + 1
        form = {
          'incomeEntries' => [
            {
              'monthlyIncome' => 2_000 * income_multiplier,
              'recipient' => 'SURVIVING_SPOUSE',
              'recipientName' => 'Jane Doe',
              'incomeType' => key,
              'incomeTypeOther' => key == 'OTHER' ? 'Other Source' : nil,
              'incomePayer' => 'Company XYZ'
            }
          ]
        }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_income_fields(form['incomeEntries'])
        expect(service.fields).to include(
          'CB_INC_RECIPIENT1_SP' => true,
          'CB_INC_RECIPIENT1_CHILD' => false,
          'NAME_OF_CHILD_INCOMETYPE1' => 'Jane Doe',
          'CB_INCOMETYPE1_SS' => key == 'SOCIAL_SECURITY',
          'CB_INCOMETYPE1_PENSION' => key == 'PENSION_RETIREMENT',
          'CB_INCOMETYPE1_CIVIL' => key == 'CIVIL_SERVICE',
          'CB_INCOMETYPE1_INTEREST' => key == 'INTEREST_DIVIDENDS',
          'CB_INCOMETYPE1_OTHER' => key == 'OTHER',
          'CB_INCOMETYPE1_OTHERSPECIFY' => (key == 'OTHER' ? 'Other Source' : nil),
          'INCOME_PAYER_1' => 'Company XYZ'
        )
      end
    end
  end

  describe '#monthly_income_keys' do
    it 'returns the keys with income_num inserted' do
      income_num = 3
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      income_keys = service.monthly_income_keys(income_num)
      expect(income_keys[:full]).to eq('MONTHLY_GROSS_3')
      expect(income_keys[:thousands]).to eq('MONTHLY_GROSS_3_THSNDS')
      expect(income_keys[:hundreds]).to eq('MONTHLY_GROSS_3_HNDRDS')
      expect(income_keys[:cents]).to eq('MONTHLY_GROSS_3_CENTS')
    end
  end
end
