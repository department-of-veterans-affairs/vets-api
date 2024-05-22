# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/fsr_form_transform/full_transform_service'

RSpec.describe DebtsApi::V0::FsrFormTransform::FullTransformService, type: :service do
  let(:pre_transform_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
  end
  let(:post_transform_fsr_form_data) do
    get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
  end

  describe '#transform' do
    it 'generates an acceptable FSR' do
      transformer = described_class.new(pre_transform_fsr_form_data)
      expect(transformer.transform).to eq(post_transform_fsr_form_data)
    end
  end
end
