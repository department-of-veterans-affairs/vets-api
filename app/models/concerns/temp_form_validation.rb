# frozen_string_literal: true

module TempFormValidation
  extend ActiveSupport::Concern

  included do
    attr_accessor(:form)
    validate(:form_matches_schema, on: :create)
  end

  private

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def form_matches_schema
    errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM_ID], parsed_form))
  end
end
