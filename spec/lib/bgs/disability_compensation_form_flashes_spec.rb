# frozen_string_literal: true

require 'rails_helper'
require 'bgs/disability_compensation_form_flashes'

Rspec.describe BGS::DisabilityCompensationFormFlashes do
  subject { described_class.new(user, form_content) }

  let(:form_content) do
    JSON.parse(
      File.read('spec/support/disability_compensation_form/all_claims_with_0781_fe_submission.json')
    )
  end

  let(:flashes) { ['Homeless', 'Priority Processing - Veteran over age 85', 'POW'] }
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  describe '#translate' do
    it 'returns correctly flashes to send to async job' do
      expect(subject.translate).to eq flashes
    end
  end
end
