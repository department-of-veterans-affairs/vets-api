# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form8940'

describe EVSS::DisabilityCompensationForm::Form8940 do
  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/front_end_submission_with_8940.json')
    )
  end
  let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_8940.json')) }
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
