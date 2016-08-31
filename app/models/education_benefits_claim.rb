class EducationBenefitsClaim < ActiveRecord::Base
  FORM_SCHEMA = JSON.parse(File.read(Rails.root.join("app", "vets-json-schema", "dist", "edu-benefits-schema.json")))

  validates(:form, presence: true)
  validate(:form_matches_schema)

  attr_encrypted(:form, key: ENV["DB_ENCRYPTION_KEY"])

  # initially only completed claims are allowed, later we can allow claims that dont have a submitted_at yet
  before_validation(:set_submitted_at, on: :create)
  before_save(:set_form_to_json)
  after_save(:parse_json_form)
  after_initialize(:parse_json_form)

  private

  def parse_json_form
    self.form = JSON.parse(form) if form.is_a?(String)
  end

  def set_form_to_json
    self.form = form.to_json if form.is_a?(Hash)
  end

  def form_matches_schema
    errors[:form].concat(JSON::Validator.fully_validate(FORM_SCHEMA, form))

    true
  end

  def set_submitted_at
    self.submitted_at = Time.zone.now
  end
end
