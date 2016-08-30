class EducationBenefitsClaim < ActiveRecord::Base
  # TODO: encrypt sensitive information in education_benefits_claims #42
  FORM_SCHEMA = JSON.parse(File.read(Rails.root.join("app", "vets-json-schema", "dist", "edu-benefits-schema.json")))

  validates(:form, presence: true)
  validate(:form_matches_schema)

  # initially only completed claims are allowed, later we can allow claims that dont have a submitted_at yet
  before_validation(:set_submitted_at, on: :create)

  private

  def form_matches_schema
    errors[:form].concat(JSON::Validator.fully_validate(FORM_SCHEMA, form))

    true
  end

  def set_submitted_at
    self.submitted_at = Time.zone.now
  end
end
