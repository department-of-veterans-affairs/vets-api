# frozen_string_literal: true
require 'attr_encrypted'
class SavedClaim < ActiveRecord::Base
  validates(:form, presence: true)
  validate(:form_matches_schema)
  validate(:form_must_be_string)
  attr_encrypted(:form, key: Settings.db_encryption_key)

  before_create do
    self.guid = SecureRandom.uuid
    self.form_type = self.class::FORM.upcase
  end

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
    errors[:form] << 'must be a json string' unless form_is_string
  end

  def form_matches_schema
    return unless form_is_string

    errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM], parsed_form))
  end
end
