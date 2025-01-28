# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAction, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:acting_user_verification).class_name('UserVerification').optional }
    it { is_expected.to belong_to(:subject_user_verification).class_name('UserVerification') }
    it { is_expected.to belong_to(:user_action_event) }
  end

  describe 'enum status' do
    it {
      expect(subject).to define_enum_for(:status).with_values({ initial: 'initial',
                                                                success: 'success',
                                                                error: 'error' }).backed_by_column_of_type(:enum)
    }
  end
end
