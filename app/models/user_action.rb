# frozen_string_literal: true

class UserAction < ApplicationRecord
  belongs_to :acting_user_verification, class_name: 'UserVerification', optional: true
  belongs_to :subject_user_verification, class_name: 'UserVerification'
  belongs_to :user_action_event

  enum :status, { initial: 'initial', success: 'success', error: 'error' }, validate: true
end
