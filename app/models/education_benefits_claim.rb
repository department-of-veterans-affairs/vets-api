class EducationBenefitsClaim < ActiveRecord::Base
  FORM_SCHEMA = JSON.parse(File.read(Rails.root.join("app", "vets-json-schema", "dist", "edu-benefits-schema.json")))

  validates(:form, presence: true)
  validate(:form_matches_schema)

  attr_encrypted(:form, key: ENV["DB_ENCRYPTION_KEY"])

  # initially only completed claims are allowed, later we can allow claims that dont have a submitted_at yet
  before_validation(:set_submitted_at, on: :create)
  after_initialize(:parse_json_form)
  around_save(:set_form_to_json)

  # This converts the form data into an OpenStruct object so that the template
  # rendering can be cleaner. Piping it through the JSON serializer was a quick
  # and easy way to deeply transform the object.
  def open_struct_form
    @application ||= JSON.parse(self['form'].to_json, object_class: OpenStruct)
    @application.form = application_type
    @application
  end

  def self.unprocessed_for(date)
    where(processed_at: nil).where('submitted_at > ? and submitted_at < ?', date.beginning_of_day, date.end_of_day)
  end

  # TODO: Add logic for determining field type(s) that need to be places in the application header
  def application_type
    return 'CH1606' if @application.chapter1606
  end

  private

  def form_matches_schema
    errors[:form].concat(JSON::Validator.fully_validate(FORM_SCHEMA, form))
  end

  def parse_json_form
    self.form = JSON.parse(form) if form.is_a?(String)
  end

  def set_form_to_json
    self.form = form.to_json if form.is_a?(Hash)
    yield
    parse_json_form
  end

  def set_submitted_at
    self.submitted_at = Time.zone.now
  end
end
