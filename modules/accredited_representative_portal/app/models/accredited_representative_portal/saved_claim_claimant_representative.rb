# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentative < ApplicationRecord
    belongs_to :saved_claim, class_name: '::SavedClaim'

    before_validation :set_claimant_type
    validates :power_of_attorney_holder_type, inclusion: { in: PowerOfAttorneyHolder::Types::ALL }

    ##
    # TODO: Extract a common constant?
    #
    ClaimantTypes = PowerOfAttorneyRequest::ClaimantTypes

    enum(
      :claimant_type,
      ClaimantTypes::ALL.index_by(&:itself),
      validate: true
    )

    private

    def set_claimant_type
      self.claimant_type =
        if saved_claim.parsed_form['dependent']
          ClaimantTypes::DEPENDENT
        elsif saved_claim.parsed_form['veteran']
          ClaimantTypes::VETERAN
        end
    end
  end
end
