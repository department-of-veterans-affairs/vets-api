# frozen_string_literal: true

class UserAction < ApplicationRecord
  belongs_to :acting_user_verification, class_name: 'UserVerification', optional: true
  belongs_to :subject_user_verification, class_name: 'UserVerification'
  belongs_to :user_action_event

  enum :status, { initial: 'initial', success: 'success', error: 'error' }, validate: true

  default_scope { order(created_at: :desc) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[status user_action_event created_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user_action_event]
  end
end
