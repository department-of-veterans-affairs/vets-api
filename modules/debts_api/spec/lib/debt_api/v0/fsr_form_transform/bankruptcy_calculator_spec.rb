# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/bankruptcy_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::BankruptcyCalculator, type: :service do
  describe '#initialize' do
    let(:pre_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
    end
    let(:post_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
    end

    def get_bankruptcy_data
      transformer = described_class.new(pre_transform_fsr_form_data)
      @data = transformer.get_bankruptcy_data
    end

    describe '#get_bankruptcy_data' do
      before do
        get_bankruptcy_data
      end

      it 'gets bankruptcy data correct' do
        expected_bankruptcy_data = post_transform_fsr_form_data['additionalData']['bankruptcy']
        transformed_data = @data
        expect(expected_bankruptcy_data).to eq(transformed_data)
      end
    end
  end
end
