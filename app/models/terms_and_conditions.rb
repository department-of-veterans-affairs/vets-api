# frozen_string_literal: true

class TermsAndConditions < ApplicationRecord
  has_many :acceptances,
           class_name: 'TermsAndConditionsAcceptance',
           inverse_of: :terms_and_conditions

  scope :latest, -> { find_by(latest: true) }

  validates :name, presence: true
  validates :terms_content, presence: true
  validates :yes_content, presence: true
  validates :version, presence: true
end
