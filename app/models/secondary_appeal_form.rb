# frozen_string_literal: true

class SecondaryAppealForm < ApplicationRecord
  validates :guid, :form_id, presence: true
  validate(:form_matches_schema)
  validate(:form_must_be_string)

  belongs_to :appeal_submission

  has_kms_key
  has_encrypted :form, key: :kms_key, **lockbox_options

  private

  def form_is_string
    form.is_a?(String)
  end

  def form_must_be_string
    errors.add(:form, :invalid_format, message: 'must be a json string') unless form_is_string
  end

  def form_matches_schema
    return unless form_is_string

    schema = VetsJsonSchema::SCHEMAS[form_id]

    schema_errors = JSON::Validator.fully_validate_schema(schema, { errors_as_objects: true })
    clear_cache = false
    unless schema_errors.empty?
      Rails.logger.error('SecondaryAppealForm schema failed validation! Attempting to clear cache.', { errors: schema_errors })
      clear_cache = true
    end

    validation_errors = JSON::Validator.fully_validate(schema, JSON.parse(form), { errors_as_objects: true, clear_cache: })

    validation_errors.each do |e|
      errors.add(e[:fragment], e[:message])
      e[:errors]&.flatten(2)&.each { |nested| errors.add(nested[:fragment], nested[:message]) if nested.is_a? Hash }
    end

    unless validation_errors.empty?
      Rails.logger.error('SavedClaim form did not pass validation', { guid:, errors: validation_errors })
    end
  end
end
