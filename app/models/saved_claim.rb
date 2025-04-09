# frozen_string_literal: true

require 'pdf_fill/filler'

# Base class to hold common functionality for Claim submissions.
# Subclasses need to several constants and methods defined:
# * `FORM` should align with the identifier of the form as found in
#    the vets-json-schema struct so that validations can be run on submit
# * `CONFIRMATION` should be a small ident used as part of the confirmation
#    number to quickly determine the form/product type
# *  `regional_office()`, which returns an array or string of the location of
#    the claim processing facility
# *  `attachment_keys()` returns a list of symbols corresponding to the keys
#    in the JSON submission of file upload references. These are iterated over
#    in the `process_attachments!` method to associate the previously unmoored
#    files to the submitted claim, and to begin processing them.

class SavedClaim < ApplicationRecord
  include SetGuid

  validates(:form, presence: true)
  validate(:form_matches_schema)
  validate(:form_must_be_string)

  has_kms_key
  has_encrypted :form, key: :kms_key, **lockbox_options

  has_many :persistent_attachments, inverse_of: :saved_claim, dependent: :destroy
  has_many :form_submissions, dependent: :nullify
  has_many :claim_va_notifications, dependent: :destroy

  belongs_to :user_account, optional: true

  after_create :after_create_metrics
  after_destroy :after_destroy_metrics

  # create a uuid for this second (used in the confirmation number) and store
  # the form type based on the constant found in the subclass.
  after_initialize do
    self.form_id = self.class::FORM.upcase unless [SavedClaim::DependencyClaim].any? { |k| instance_of?(k) }
  end

  def self.add_form_and_validation(form_id)
    const_set('FORM', form_id)
    validates(:form_id, inclusion: [form_id])
  end

  # Run after a claim is saved, this processes any files and workflows that are present
  # and sends them to our internal partners for processing.
  def process_attachments!
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.find_each { |f| f.update(saved_claim_id: id) }

    Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  def confirmation_number
    guid
  end

  # Convert the json into an OStruct
  def open_struct_form
    @application ||= JSON.parse(form, object_class: OpenStruct)
  end

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def submitted_at
    created_at
  end

  def form_is_string
    form.is_a?(String)
  end

  def form_must_be_string
    errors.add(:form, :invalid_format, message: 'must be a json string') unless form_is_string
  end

  def form_matches_schema
    return unless form_is_string

    schema = VetsJsonSchema::SCHEMAS[self.class::FORM]
    clear_cache = false

    schema_errors = validate_schema(schema)
    unless schema_errors.empty?
      Rails.logger.error('SavedClaim schema failed validation! Attempting to clear cache.',
                         { form_id:, errors: schema_errors })
      clear_cache = true
    end

    validation_errors = validate_form(schema, clear_cache)
    validation_errors.each do |e|
      errors.add(e[:fragment], e[:message])
      e[:errors]&.flatten(2)&.each { |nested| errors.add(nested[:fragment], nested[:message]) if nested.is_a? Hash }
    end

    unless validation_errors.empty?
      Rails.logger.error('SavedClaim form did not pass validation', { form_id:, guid:, errors: validation_errors })
    end

    schema_errors.empty? && validation_errors.empty?
  end

  def to_pdf(file_name = nil)
    PdfFill::Filler.fill_form(self, file_name)
  end

  def update_form(key, value)
    application = parsed_form
    application[key] = value
    self.form = JSON.generate(application)
  end

  def business_line
    ''
  end

  def email
    nil
  end

  ##
  # insert notifcation after VANotify email send
  #
  # @see ClaimVANotification
  #
  def insert_notification(email_template_id)
    claim_va_notifications.create!(
      form_type: form_id,
      email_sent: true,
      email_template_id:
    )
  end

  ##
  # Find notifcation by args*
  #
  # @param email_template_id
  # @see ClaimVANotification
  #
  def va_notification?(email_template_id)
    claim_va_notifications.find_by(
      form_type: form_id,
      email_template_id:
    )
  end

  def regional_office
    []
  end

  private

  def validate_schema(schema)
    errors = JSONSchemer.validate_schema(schema).to_a
    return [] if errors.empty?

    reformatted_schemer_errors(errors)
  end

  def validate_form(schema, _clear_cache)
    errors = JSONSchemer.schema(schema).validate(parsed_form).to_a
    return [] if errors.empty?

    reformatted_schemer_errors(errors)
  end

  # This method exists to change the json_schemer errors
  # to be formatted like json_schema errors, which keeps
  # the error logging smooth and identical for both options.
  def reformatted_schemer_errors(errors)
    errors.map!(&:symbolize_keys)
    errors.each do |error|
      error[:fragment] = error[:data_pointer]
      error[:message] = error[:error]
    end
    errors
  end

  def attachment_keys
    []
  end

  def after_create_metrics
    tags = ["form_id:#{form_id}"]
    StatsD.increment('saved_claim.create', tags:)
    if form_start_date
      claim_duration = created_at - form_start_date
      StatsD.measure('saved_claim.time-to-file', claim_duration, tags:)
    end

    pdf_overflow_tracking if Flipper.enabled?(:saved_claim_pdf_overflow_tracking)
  end

  def after_destroy_metrics
    StatsD.increment('saved_claim.destroy', tags: ["form_id:#{form_id}"])
  end

  def pdf_overflow_tracking
    tags = ["form_id:#{form_id}"]
    filename = to_pdf

    # @see PdfFill::Filler
    # https://github.com/department-of-veterans-affairs/vets-api/blob/96510bd1d17b9e5c95fb6c09d74e53f66b0a25be/lib/pdf_fill/filler.rb#L88
    StatsD.increment('saved_claim.pdf.overflow', tags:) if filename.end_with?('_final.pdf')
  rescue => e
    Rails.logger.error("#{self.class} Error tracking PDF overflow", form_id:, saved_claim_id: id, error: e)
  ensure
    Common::FileHelpers.delete_file_if_exists(filename)
  end
end
