# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tooltip, type: :model do
  context 'with valid attributes' do
    subject { build(:tooltip) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:tooltip_name) }
    it { is_expected.to validate_presence_of(:last_signed_in) }
    it { is_expected.to validate_uniqueness_of(:tooltip_name).scoped_to(:user_account_id) }
  end

  context 'with invalid attributes' do
    it 'is invalid without a tooltip_name' do
      tooltip = build(:tooltip, tooltip_name: nil)
      expect(tooltip).not_to be_valid
      expect(tooltip.errors[:tooltip_name]).to include('can\'t be blank')
    end

    it 'is invalid without a last_signed_in' do
      tooltip = build(:tooltip, last_signed_in: nil)
      expect(tooltip).not_to be_valid
      expect(tooltip.errors[:last_signed_in]).to include('can\'t be blank')
    end

    it 'is invalid with a duplicate tooltip_name for the same user_account' do
      user_account = create(:user_account)
      create(:tooltip, user_account:, tooltip_name: 'duplicate_name')
      tooltip = build(:tooltip, user_account:, tooltip_name: 'duplicate_name')
      expect(tooltip).not_to be_valid
      expect(tooltip.errors[:tooltip_name]).to include('has already been taken')
    end
  end

  context 'associations' do
    it 'belongs to a user_account' do
      tooltip = build(:tooltip)
      expect(tooltip).to respond_to(:user_account)
    end
  end
end
