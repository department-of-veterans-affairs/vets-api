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

  def regional_office
    [] # TODO: (kevinmirc): This needs to be the plannedClinic provided on
  end
end
