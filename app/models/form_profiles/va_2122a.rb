# frozen_string_literal: true

require 'vets/model'

module VA2122a
  class IdentityValidation
    include Vets::Model

    attribute :has_icn, Bool
    attribute :has_participant_id, Bool
    attribute :is_loa3, Bool
  end
end

class FormProfiles::VA2122a < FormProfile
  attribute :identity_validation, VA2122a::IdentityValidation

  def prefill
    prefill_identity_validation

    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/claimant-type'
    }
  end

  private

  def prefill_identity_validation
    @identity_validation = VA2122::IdentityValidation.new(
      has_icn: user.icn.present?,
      has_participant_id: user.participant_id.present?,
      is_loa3: user.loa3?
    )
  end
end
