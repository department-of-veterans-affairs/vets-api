# frozen_string_literal: true

class AccreditedOrganization < ApplicationRecord
  # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :accredited_individuals,
                          class: 'AccreditedIndividual',
                          join_table: 'accredited_individuals_accredited_organizations'
  # rubocop:enable Rails/HasAndBelongsToMany

  validates :ogc_id, :poa_code, presence: true
  validates :poa_code, length: { is: 3 }
  validates :poa_code, uniqueness: true
end
