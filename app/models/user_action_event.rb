# frozen_string_literal: true

class UserActionEvent < ApplicationRecord
  has_many :user_actions, dependent: :restrict_with_exception

  validates :details, presence: true
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :event_id, presence: true, uniqueness: { case_sensitive: true }
  # rubocop:enable Rails/UniqueValidationWithoutIndex
  validates :event_type, presence: true

  enum :event_type, { authentication: 0, profile: 1 }

  before_validation :strip_event_id
  before_update :prevent_event_id_change

  private

  def strip_event_id
    self.event_id = event_id.strip if event_id.present?
  end

  def prevent_event_id_change
    if event_id_changed? && persisted?
      errors.add(:event_id, 'cannot be changed')
      throw(:abort)
    end
  end
end
