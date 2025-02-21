# frozen_string_literal: true

class SavedClaim::NoticeOfDisagreement < SavedClaim
  has_one :appeal_submission, class_name: 'AppealSubmission', foreign_key: :submitted_appeal_uuid, primary_key: :guid,
                              dependent: nil, inverse_of: :saved_claim_nod, required: false

  FORM = '10182'

  def form_matches_schema
    return unless form_is_string

    schema = VetsJsonSchema::SCHEMAS['NOD-CREATE-REQUEST-BODY_V1']
    schema.delete '$schema' # workaround for JSON::Schema::SchemaError (Schema not found)

    validation_errors = JSON::Validator.fully_validate(schema, parsed_form)

    unless validation_errors.empty?
      Rails.logger.warn("SavedClaim: schema validation error detected for form #{FORM}", validation_errors)
    end

    true # allow storage of all requests for debugging
  rescue JSON::Schema::ReadFailed => e
    Rails.logger.warn("SavedClaim: form_matches_schema error raised for form #{FORM}", e)
    true
  end

  def process_attachments!
    # Inherited from SavedClaim. Disabling since this claim handles attachments separately.
    raise NotImplementedError, 'Not Implemented for Form 10182'
  end
end
