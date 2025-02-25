# frozen_string_literal: true

class UserActionEvent < ApplicationRecord
  has_many :user_actions, dependent: :restrict_with_exception

  EVENT_TYPES = %w[authentication].freeze

  validates :details, presence: true
  validates :identifier, presence: true, uniqueness: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
end
