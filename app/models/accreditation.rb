# frozen_string_literal: true

class Accreditation < ApplicationRecord
  # Acts as the join between AccreditedIndividual and AccreditedOrganization and is meant to store information that
  # lives at the grain between the two models. For example, can_accept_reject_poa is a permission that needs to be
  # set for each organization a representative is accredited with.
  #
  # @note for can_accept_reject_poa that a slight change
  # to implementation might be needed to support attorneys and claims agents since they do not have organization
  # accreditations.

  belongs_to :accredited_individual
  belongs_to :accredited_organization

  validates :accredited_organization_id, uniqueness: { scope: :accredited_individual_id }
end
