# frozen_string_literal: true
class EducationBenefitsClaim < ActiveRecord::Base
  FORM_SCHEMA = JSON.parse(File.read(Rails.root.join('app', 'vets-json-schema', 'dist', 'edu-benefits-schema.json')))

  validates(:form, presence: true)
  validate(:form_matches_schema)
  validate(:form_must_be_string)

  attr_encrypted(:form, key: ENV['DB_ENCRYPTION_KEY'])

  # initially only completed claims are allowed, later we can allow claims that dont have a submitted_at yet
  before_validation(:set_submitted_at, on: :create)

  # This converts the form data into an OpenStruct object so that the template
  # rendering can be cleaner. Piping it through the JSON serializer was a quick
  # and easy way to deeply transform the object.
  def open_struct_form
    @application ||= JSON.parse(form, object_class: OpenStruct)
    @application.form = application_type
    @application
  end

  def self.unprocessed
    where(processed_at: nil)
  end

  def regional_office
    EducationForm::EducationFacility.regional_office_for(open_struct_form)
  end

  # TODO: Add logic for determining field type(s) that need to be places in the application header
  def application_type
    return 'CH1606' if @application.chapter1606
  end

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def confirmation_number
    "vets_gov_#{self.class.to_s.underscore}_#{id}"
  end

  private

  def form_is_string
    form.is_a?(String)
  end

  # if the form is a hash olive_branch will convert all the keys to underscore and break our json schema validation
  def form_must_be_string
    errors[:form] << 'must be a json string' unless form_is_string
  end

  def form_matches_schema
    return unless form_is_string

    errors[:form].concat(JSON::Validator.fully_validate(FORM_SCHEMA, parsed_form))
  end

  def set_submitted_at
    self.submitted_at = Time.zone.now
  end
end
