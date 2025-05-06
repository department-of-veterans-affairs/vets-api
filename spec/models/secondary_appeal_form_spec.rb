# frozen_string_literal: true

require 'rails_helper'

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

  describe 'incomplete scope' do
    let(:complete_form) { create(:secondary_appeal_form4142, delete_date: 10.days.ago) }
    let(:incomplete_form) { create(:secondary_appeal_form4142) }

    it 'only returns records without a delete_date' do
      results = SecondaryAppealForm.incomplete
      expect(results).to contain_exactly(incomplete_form)
    end
  end
end
