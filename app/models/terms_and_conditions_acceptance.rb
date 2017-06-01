# frozen_string_literal: true

class TermsAndConditionsAcceptance < ActiveRecord::Base
  belongs_to :terms_and_conditions

  scope :for_user, ->(user) { where(user_uuid: user.uuid) }
  scope :for_terms, ->(terms_name) { joins(:terms_and_conditions).where(terms_and_conditions: { name: terms_name }) }
  scope :for_latest, -> { joins(:terms_and_conditions).find_by(terms_and_conditions: { latest: true }) }

  validates :user_uuid, presence: true
  validates :user_uuid, uniqueness: { scope: :terms_and_conditions_id }
end
