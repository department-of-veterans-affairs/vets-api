# frozen_string_literal: true

require 'rails_helper'

describe EVSS::DisabilityCompensationForm::Form8940 do
  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/all_claims_with_8940_fe_submission.json')
    )
  end
  let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_8940.json')) }
  let(:user) { create(:disabilities_compensation_user) }

  subject { described_class.new(user, form_content) }

  describe '#translate' do
    it 'returns correctly formatted json to send to async job' do
      Rails.logger.info('Form8940 All Claims', JSON.parse(subject.translate).to_json)
      expect(JSON.parse(subject.translate)).to eq expected_output
    end
  end
end
