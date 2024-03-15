# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/asset_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::AssetCalculator, type: :service do
  let(:maximal_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures//pre_submission_fsr/fsr_assets_form')
  end

  before do
    calculate_total_assets
  end

  def calculate_total_assets
    calculations_controller = described_class.new(maximal_fsr_form_data)
    @total_assets = calculations_controller.get_total_assets
  end

  describe '#calculate_assets' do
    it 'calculates total assets' do
      expect(@total_assets).not_to be_nil
    end

    it 'calculates total assets accurately' do
      expect(@total_assets).to eq(2120)
    end
  end
end
