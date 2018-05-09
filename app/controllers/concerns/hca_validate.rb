# frozen_string_literal: true

module HcaValidate
  extend ActiveSupport::Concern
  FORM_ID = '10-10EZ'

  included do
    skip_before_action(:authenticate)
    before_action(:tag_rainbows)
  end

  def validate!(form)
    validation_errors = JSON::Validator.fully_validate(
      VetsJsonSchema::SCHEMAS[FORM_ID],
      form, validate_schema: true
    )

    raise Common::Exceptions::SchemaValidationErrors, validation_errors if validation_errors.present?
  end
end
