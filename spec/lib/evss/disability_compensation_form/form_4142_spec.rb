# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form4142'

describe EVSS::DisabilityCompensationForm::Form4142 do
  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/front_end_submission_with_4142.json')
    )
  end
  let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_4142.json')) }
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  subject { described_class.new(user, form_content) }

  describe '#translate' do
    it 'should return correctly formatted json to send to async job' do
      expect(JSON.parse(subject.translate)).to eq expected_output
    end
  end
end
