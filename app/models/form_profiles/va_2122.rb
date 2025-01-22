# frozen_string_literal: true

module VA2122
  class IdentityValidation
    include Virtus.model

    attribute :has_icn, Boolean
    attribute :has_participant_id, Boolean
    attribute :is_loa3, Boolean
  end
end

class FormProfiles::VA2122 < FormProfile
  attribute :identity_validation, VA2122::IdentityValidation

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
