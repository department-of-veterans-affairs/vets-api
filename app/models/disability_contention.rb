# frozen_string_literal: true

class DisabilityContention < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :medical_term, presence: true

  def self.suggested(name_part)
    DisabilityContention.where('medical_term ILIKE ? OR lay_term ILIKE ?', "%#{name_part}%", "%#{name_part}%")
  end
end
