# frozen_string_literal: true

class SavedClaim::SupplementalClaim < SavedClaim
  FORM = '20-0995'

  def form_matches_schema
    return unless form_is_string

    schema = VetsJsonSchema::SCHEMAS['SC-CREATE-REQUEST-BODY_V1']
    schema.delete '$schema' # workaround for JSON::Schema::SchemaError (Schema not found)

    validation_errors = JSON::Validator.fully_validate(schema, parsed_form)

    unless validation_errors.empty?
      Rails.logger.warn("SavedClaim: form schema errors detected for form #{FORM}", validation_errors)
    end

    true # allow storage of invalid requests for debugging
  end

  def process_attachments!
    # Inherited from SavedClaim. Disabling since this claim handles attachments separately.
    raise NotImplementedError, 'Not Implemented for Form 20-0995'
  end
end
