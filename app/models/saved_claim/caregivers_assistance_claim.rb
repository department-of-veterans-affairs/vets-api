# frozen_string_literal: true

require 'pdf_fill/filler'

class SavedClaim::CaregiversAssistanceClaim < SavedClaim
  FORM = '10-10CG'

  has_one :submission,
          class_name: 'Form1010cg::Submission',
          foreign_key: 'claim_guid',
          primary_key: 'guid',
          inverse_of: :claim,
          dependent: :destroy

  accepts_nested_attributes_for :submission

  before_destroy(:destroy_attachment)

  def process_attachments!
    # Inherited from SavedClaim. Disabling since this claim does not require attachements.
    raise NotImplementedError, 'Not Implemented for Form 10-10CG'
  end

  def to_pdf(filename = nil, **)
    # We never save the claim, so we don't have an id to provide for the filename.
    # Instead we'll create a filename with this format "10-10cg_{uuid}"
    name = filename || guid
    PdfFill::Filler.fill_form(self, name, **)
  rescue => e
    Rails.logger.error("Failed to generate PDF: #{e.message}")
    PersonalInformationLog.create(data: { form: parsed_form, file_name: name },
                                  error_class: '1010CGPdfGenerationError')
    raise
  end

  # SavedClaims require regional_office to be defined, CaregiversAssistanceClaim has no purpose for it.
  #
  # CaregiversAssistanceClaims are not processed regional VA offices.
  # The claim's form will contain a "Planned Clinic" (a VA facility that the end-user provided in the form).
  # This facility is where the end-user's point of contact will be for post-submission processing.
  def regional_office
    []
  end

  def form_subjects
    if form.nil?
      []
    else
      parsed_form.keys.find_all do |k|
        %w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo].include?(k)
      end
    end
  end

  def veteran_data
    parsed_form['veteran'] unless form.nil?
  end

  def primary_caregiver_data
    parsed_form['primaryCaregiver'] unless form.nil?
  end

  def secondary_caregiver_one_data
    parsed_form['secondaryCaregiverOne'] unless form.nil?
  end

  def secondary_caregiver_two_data
    parsed_form['secondaryCaregiverTwo'] unless form.nil?
  end

  private

  def destroy_attachment
    return if form.blank?

    Form1010cg::Attachment.find_by(guid: parsed_form['poaAttachmentId'])&.destroy!
  end
end
