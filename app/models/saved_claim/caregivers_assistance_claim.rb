# frozen_string_literal: true

class SavedClaim::CaregiversAssistanceClaim < SavedClaim
  FORM = '10-10CG'

  def process_attachments!
    # Inherited from SavedClaim. Disabling since this claim does not require attachements.
    raise NotImplementedError, 'Not Implemented for Form 10-10CG'
  end

  def to_pdf
    # Inherited from SavedClaim. Disabling until it's implemented for 10-10CG (requires code in PDFFill::Filler)
    raise NotImplementedError, 'Not Implemented for Form 10-10CG'
  end

  # SavedClaims require regional_office to be defined, CaregiversAssistanceClaim has no purpose for it.
  #
  # CaregiversAssistanceClaims are not processed regional VA offices.
  # The claim's form will contain a "Planned Clinic" (a VA facility that the end-user provided in the form).
  # This facility is where the end-user's point of contact will be for post-submission processing.
  def regional_office
    []
  end
end
