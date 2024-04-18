# frozen_string_literal: true

class AccreditedIndividual < ApplicationRecord
  # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :accredited_organizations,
                          class: 'AccreditedOrganization',
                          join_table: 'accredited_individuals_accredited_organizations'

  # rubocop:enable Rails/HasAndBelongsToMany

  validates :ogc_id, :registration_number, :individual_type, presence: true
  validates :poa_code, length: { is: 3 }, allow_blank: true
  validates :individual_type, uniqueness: { scope: :registration_number }

  enum individual_type: {
    'attorney' => 'attorney',
    'claims_agent' => 'claims_agent',
    'representative' => 'representative'
  }
end
