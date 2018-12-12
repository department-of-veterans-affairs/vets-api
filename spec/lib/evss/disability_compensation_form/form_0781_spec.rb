# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form0781'

describe EVSS::DisabilityCompensationForm::Form0781 do
  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/all_claims_with_0781_fe_submission.json')
    )
  end
  let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_0781.json')) }
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  subject { described_class.new(user, form_content) }

  describe '#translate' do
    it 'should return correctly formatted json to send to async job' do
      expect(subject.translate).to eq expected_output
    end
  end
end
