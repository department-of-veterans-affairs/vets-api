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
  has_many :claim_va_notifications, dependent: :destroy

  has_many :form_submissions, dependent: :nullify
  has_many :bpds_submissions, class_name: 'BPDS::Submission', dependent: :nullify
  has_many :lighthouse_submissions, class_name: 'Lighthouse::Submission', dependent: :nullify
  has_many :claims_evidence_api_submissions, class_name: 'ClaimsEvidenceApi::Submission', dependent: :nullify

  has_many :parent_of_groups, class_name: 'SavedClaimGroup', foreign_key: 'parent_claim_id',
                              dependent: :destroy, inverse_of: :parent

  has_many :child_of_groups, class_name: 'SavedClaimGroup',
                             dependent: :destroy, inverse_of: :child

  belongs_to :user_account, optional: true

  after_create :after_create_metrics
  after_destroy :after_destroy_metrics

  # create a uuid for this second (used in the confirmation number) and store
  # the form type based on the constant found in the subclass.
  after_initialize do
    unless [SavedClaim::DependencyClaim, DependentsBenefits::SavedClaim].any? { |k| instance_of?(k) }
      self.form_id = self.class::FORM.upcase
    end
  end

  def self.add_form_and_validation(form_id)
    const_set('FORM', form_id)
    validates(:form_id, inclusion: [form_id])
  end

  def self.openapi_doc
    Rails.cache.fetch('saved_claim/openapi_doc') do
      doc = JSON.parse(Rails.public_path.join('openapi.json').read)
      doc.freeze
    end
  end

  # Get cached request body schema for a given operation_id
  def self.openapi_request_body_schema(operation_id)
    Rails.cache.fetch("saved_claim/openapi_schema/#{operation_id}") do
      # Will be populated by the instance method
      nil
    end
  end

  # Set cached request body schema for a given operation_id
  def self.cache_openapi_request_body_schema(operation_id, schema)
    Rails.cache.write("saved_claim/openapi_schema/#{operation_id}", schema)
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

    schema = resolved_validation_schema
    return handle_missing_schema unless schema

    schema_valid = log_and_validate_schema(schema)
    return unless schema_valid

    log_and_validate_form(schema)
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

  # the VBMS document type for _this_ claim type
  # @see modules/claims_evidence_api/documentation/doctypes.json
  def document_type
    10 # Unknown
  end

  # alias for document_type
  # using `alias_method` causes 'doctype' to always return 10
  def doctype
    document_type
  end

  def email
    nil
  end

  # insert notifcation after VANotify email send
  #
  # @see ClaimVANotification
  def insert_notification(email_template_id)
    claim_va_notifications.create!(
      form_type: form_id,
      email_sent: true,
      email_template_id:
    )
  end

  # Find notifcation by args*
  #
  # @param email_template_id
  # @see ClaimVANotification
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

  def handle_missing_schema
    message = "Schema for #{self.class.name} (form_id: #{form_id}) could not be resolved"
    Rails.logger.error(message)
    if Rails.env.development? || Rails.env.test?
      raise KeyError, message
    else
      errors.add(:base, message)
      false
    end
  end

  def log_and_validate_schema(schema)
    schema_errors = validate_schema(schema)
    return true if schema_errors.empty?

    Rails.logger.error('SavedClaim schema failed validation.',
                       { form_id:, errors: schema_errors })

    false
  end

  def log_and_validate_form(schema)
    validation_errors = validate_form(schema)
    validation_errors.each do |e|
      errors.add(e[:fragment], e[:message])
      e[:errors]&.flatten(2)&.each do |nested|
        errors.add(nested[:fragment], nested[:message]) if nested.is_a?(Hash)
      end
    end

    unless validation_errors.empty?
      Rails.logger.error('SavedClaim form did not pass validation',
                         { form_id:, guid:, errors: validation_errors })
    end

    validation_errors.empty?
  end

  def validate_schema(schema)
    # Validate the schema itself against the chosen meta schema/dialect
    meta = selected_meta_schema
    errors = JSONSchemer.validate_schema(schema, meta_schema: meta).to_a
    return [] if errors.empty?

    reformatted_schemer_errors(errors)
  end

  def validate_form(schema)
    # Validate the form instance against the selected schema and dialect
    meta = selected_meta_schema
    errors = JSONSchemer.schema(schema, meta_schema: meta).validate(parsed_form).to_a
    return [] if errors.empty?

    reformatted_schemer_errors(errors)
  end

  # This method exists to change the json_schemer errors
  # to be formatted like json_schema errors, which keeps
  # the error logging smooth and identical for both options.
  # This method also filters out the `data` key because it could
  # potentially contain pii.
  def reformatted_schemer_errors(errors)
    errors.map do |error|
      symbolized = error.symbolize_keys
      {
        data_pointer: symbolized[:data_pointer],
        error: symbolized[:error],
        details: symbolized[:details],
        schema: symbolized[:schema],
        root_schema: symbolized[:root_schema],
        message: symbolized[:error],
        fragment: symbolized[:data_pointer]
      }
    end
  end

  def attachment_keys
    []
  end

  def after_create_metrics
    tags = ["form_id:#{form_id}", "doctype:#{document_type}"]
    StatsD.increment('saved_claim.create', tags:)
    if form_start_date
      claim_duration = created_at - form_start_date
      StatsD.measure('saved_claim.time-to-file', claim_duration, tags:)
    end

    pdf_overflow_tracking if Flipper.enabled?(:saved_claim_pdf_overflow_tracking)
  end

  def after_destroy_metrics
    tags = ["form_id:#{form_id}", "doctype:#{document_type}"]
    StatsD.increment('saved_claim.destroy', tags:)
  end

  def pdf_overflow_tracking
    tags = ["form_id:#{form_id}", "doctype:#{document_type}"]

    form_class = PdfFill::Filler::FORM_CLASSES[form_id]
    unless form_class
      return Rails.logger.info("#{self.class} Skipping tracking PDF overflow", form_id:, saved_claim_id: id)
    end

    filename = to_pdf

    # @see PdfFill::Filler
    # https://github.com/department-of-veterans-affairs/vets-api/blob/96510bd1d17b9e5c95fb6c09d74e53f66b0a25be/lib/pdf_fill/filler.rb#L88
    StatsD.increment('saved_claim.pdf.overflow', tags:) if filename.end_with?('_final.pdf')
  rescue => e
    Rails.logger.warn("#{self.class} Error tracking PDF overflow", form_id:, saved_claim_id: id, error: e)
  ensure
    Common::FileHelpers.delete_file_if_exists(filename)
  end

  # Schema resolution and dialect selection
  def resolved_validation_schema
    case schema_source
    when :openapi3
      openapi_request_body_schema
    else
      VetsJsonSchema::SCHEMAS[self.class::FORM]
    end
  end

  def schema_source
    # Subclasses may override or set SCHEMA_SOURCE = :openapi3 to opt into OpenAPI validation
    desired = if self.class.const_defined?(:SCHEMA_SOURCE, false)
                self.class::SCHEMA_SOURCE.to_s.downcase.to_sym
              else
                :vets_json_schema
              end

    return :openapi3 if desired == :openapi3 && Flipper.enabled?(:saved_claim_openapi_validation)

    :vets_json_schema
  end

  def selected_meta_schema
    case schema_source
    when :openapi3
      # Use OpenAPI 3.0 dialect for schema and instance validation
      JSONSchemer.openapi30
    else
      # Default to JSON Schema 2020-12 for legacy vets-json-schema validations
      JSONSchemer.draft202012
    end
  end

  def openapi_request_body_schema
    op_id = openapi_operation_id

    # Check cache first
    cached = self.class.openapi_request_body_schema(op_id)
    return cached if cached

    # Build and cache the schema
    operation = find_openapi_operation(self.class.openapi_doc, op_id)
    raise KeyError, "OpenAPI operation not found: #{op_id}" unless operation

    request_schema = operation.dig('requestBody', 'content', 'application/json', 'schema')
    raise KeyError, "OpenAPI requestBody schema not found for: #{op_id}" unless request_schema

    schema_with_components = request_schema.deep_dup
    schema_with_components['components'] = self.class.openapi_doc['components'] if self.class.openapi_doc['components']

    # Cache for future requests
    self.class.cache_openapi_request_body_schema(op_id, schema_with_components.freeze)

    schema_with_components
  end

  def openapi_operation_id
    # Subclasses must define OPENAPI_OPERATION_ID when using OpenAPI validation
    return self.class::OPENAPI_OPERATION_ID if self.class.const_defined?(:OPENAPI_OPERATION_ID)

    raise KeyError, "OPENAPI_OPERATION_ID must be defined for #{self.class.name} when using :openapi3 schema_source"
  end

  def find_openapi_operation(openapi_doc, operation_id)
    paths = openapi_doc['paths'] || {}
    paths.each_value do |methods|
      methods.each_value do |operation|
        return operation if operation.is_a?(Hash) && operation['operationId'] == operation_id
      end
    end
    nil
  end
end
