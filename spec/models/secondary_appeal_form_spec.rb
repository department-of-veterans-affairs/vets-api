# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe SecondaryAppealForm, type: :model do
  subject { build(:secondary_appeal_form4142) }

  describe 'validations' do
    before do
      expect(subject).to be_valid
    end

    it { is_expected.to validate_presence_of(:guid) }
    it { is_expected.to validate_presence_of(:form_id) }
    it { is_expected.to validate_presence_of(:form) }
  end
end
