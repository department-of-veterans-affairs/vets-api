# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/discretionary_income_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::DiscretionaryIncomeCalculator, type: :service do
  describe '#initialize' do
    let(:pre_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
    end
    let(:post_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
    end

    def get_data
      transformer = described_class.new(pre_transform_fsr_form_data)
      @data = transformer.get_data
    end

    describe '#get_data' do
      before do
        get_data
      end

      it 'gets discretionary income correct' do
        expected_discretionary_income_data = post_transform_fsr_form_data['discretionaryIncome']
        expect(expected_discretionary_income_data).to eq(@data)
      end
    end
  end
end
