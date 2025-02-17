# frozen_string_literal: true

class UserActionEvent < ApplicationRecord
  has_many :user_actions, dependent: :restrict_with_exception

  validates :details, presence: true
  validates :event_id, presence: true
  validates :event_type, presence: true
end
