# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/personal_data_calculator'

RSpec.describe DebtsApi::V0::FsrFormTransform::PersonalDataCalculator, type: :service do
  describe '#initialize' do
    let(:pre_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
    end
    let(:post_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
    end

    def get_personal_data
      transformer = described_class.new(pre_transform_fsr_form_data)
      @data = transformer.get_personal_data
    end

    describe '#get_personal_data' do
      before do
        get_personal_data
      end

      it 'gets personal data correct' do
        expected_personal_data = post_transform_fsr_form_data['personalData']
        expect(expected_personal_data).to eq(@data)
      end
    end
  end
end
