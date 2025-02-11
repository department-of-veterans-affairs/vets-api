# frozen_string_literal: true

class UserActionEvent < ApplicationRecord
  has_many :user_actions, dependent: :restrict_with_exception

  validates :details, presence: true
  validates :slug, presence: true, uniqueness: true

  attribute :event_type, :integer
  attribute :slug, :string
  enum :event_type, { authentication: 0, profile: 1 }
end
