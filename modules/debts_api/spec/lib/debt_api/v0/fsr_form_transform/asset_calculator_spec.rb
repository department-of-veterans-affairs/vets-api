# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/asset_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::AssetCalculator, type: :service do
  let(:maximal_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures//pre_submission_fsr/fsr_assets_form')
  end
  let(:pre_transform_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
  end
  let(:post_transform_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
  end

  describe '#calculate_assets' do
    let(:calculator) { described_class.new(maximal_fsr_form_data) }
    let(:total_assets) { calculator.get_total_assets }

    it 'calculates total assets' do
      expect(total_assets).not_to be_nil
    end

    it 'calculates total assets accurately' do
      expect(total_assets).to eq(2120)
    end
  end

  describe '#transform_assets' do
    it 'handles nil questions' do
      pre_transform_fsr_form_data.delete('questions')
      calculator = described_class.new(pre_transform_fsr_form_data)
      expect { calculator.transform_assets }.not_to raise_error
    end

    context 'with full payload' do
      let(:assets) do
        calculator = described_class.new(pre_transform_fsr_form_data)
        calculator.transform_assets
      end

      it 'gets cashInBank right' do
        expected_cash_in_bank = post_transform_fsr_form_data['assets']['cashInBank']
        actual_cash_in_bank = assets['cashInBank']
        expect(actual_cash_in_bank).to eq(expected_cash_in_bank)
      end

      it 'gets cashOnHand right' do
        expected_cash_on_hand = post_transform_fsr_form_data['assets']['cashOnHand']
        actual_cash_on_hand = assets['cashOnHand']
        expect(actual_cash_on_hand).to eq(expected_cash_on_hand)
      end

      it 'gets automobiles right' do
        expected_auto = post_transform_fsr_form_data['assets']['automobiles']
        actual_auto = assets['automobiles']
        expect(actual_auto).to eq(expected_auto)
      end

      it 'gets trailersBoatsCampers right' do
        expected_toys = post_transform_fsr_form_data['assets']['trailersBoatsCampers']
        actual_toys = assets['trailersBoatsCampers']
        expect(actual_toys).to eq(expected_toys)
      end

      it 'gets usSavingsBonds right' do
        expected_bonds = post_transform_fsr_form_data['assets']['usSavingsBonds']
        actual_bonds = assets['usSavingsBonds']
        expect(actual_bonds).to eq(expected_bonds)
      end

      it 'gets stocksAndOtherBonds right' do
        expected_stocks = post_transform_fsr_form_data['assets']['stocksAndOtherBonds']
        actual_stocks = assets['stocksAndOtherBonds']
        expect(actual_stocks).to eq(expected_stocks)
      end

      it 'gets realEstateOwned right' do
        expected_realestate = post_transform_fsr_form_data['assets']['realEstateOwned']
        actual_realestate = assets['realEstateOwned']
        expect(actual_realestate).to eq(expected_realestate)
      end

      it 'gets otherAssets right' do
        expected_other = post_transform_fsr_form_data['assets']['otherAssets']
        actual_other = assets['otherAssets']
        expect(actual_other).to eq(expected_other)
      end

      it 'gets totalAssets right' do
        expected_total = post_transform_fsr_form_data['assets']['totalAssets']
        actual_total = assets['totalAssets']
        expect(actual_total).to eq(expected_total)
      end
    end
  end
end
