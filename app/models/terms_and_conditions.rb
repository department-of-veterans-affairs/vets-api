# frozen_string_literal: true

class TermsAndConditions < ActiveRecord::Base
  has_many :terms_and_conditions_acceptances

  scope :latest, -> { find_by(latest: true) }

  validates :name, presence: true
  validates :title, presence: true
  validates :text, presence: true
  validates :version, presence: true
end
