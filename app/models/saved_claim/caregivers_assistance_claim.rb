class SavedClaim::CaregiversAssistanceClaim < SavedClaim
  FORM = '10-10CG'

  def process_attachments!
    # Inherited from SavedClaim. Disabling since this claim does not require attachements.
    raise NotImplementedError.new('Not Implemented for Form 10-10CG')
  end

  def to_pdf
    # Inherited from SavedClaim. Disabling until it's implemented for 10-10CG (requires code in PDFFill::Filler)
    raise NotImplementedError.new('Not Implemented for Form 10-10CG')
  end

  def regional_office

  end
end
