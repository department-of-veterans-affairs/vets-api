# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form4142'

describe EVSS::DisabilityCompensationForm::Form4142 do
  subject { described_class.new(user, form_content) }

  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/submit_all_claim/4142.json')
    )
  end
  let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_4142.json')) }
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  describe '#translate' do
    it 'returns correctly formatted json to send to async job' do
      expect(subject.translate).to eq expected_output
    end
  end
end
