# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form8940'

describe EVSS::DisabilityCompensationForm::Form8940 do
  subject { described_class.new(user, form_content) }

  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/submit_all_claim/8940.json')
    )
  end
  let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_8940.json')) }
  let(:user) { create(:disabilities_compensation_user) }

  describe '#translate' do
    it 'returns correctly formatted json to send to async job' do
      Rails.logger.info('Form8940 All Claims', JSON.parse(subject.translate).to_json)
      expect(JSON.parse(subject.translate)).to eq expected_output
    end
  end
end
