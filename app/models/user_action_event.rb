# frozen_string_literal: true

class UserActionEvent < ApplicationRecord
  has_many :user_actions, dependent: :restrict_with_exception

  validates :details, presence: true
  validates :identifier, presence: true, uniqueness: true
  validates :event_type, presence: true

  def self.event_types
    %w[authentication]
  end
end
