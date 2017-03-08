# frozen_string_literal: true
class EducationBenefitsClaim < ActiveRecord::Base
  FORM_SCHEMAS = IceNine.deep_freeze(
    '1990' => VetsJsonSchema::EDU_BENEFITS,
    '1995' => VetsJsonSchema::CHANGE_OF_PROGRAM,
    '1990e' => VetsJsonSchema::TRANSFER_BENEFITS,
    '5490' => VetsJsonSchema::DEPENDENTS_BENEFITS
  )
  FORM_TYPES = FORM_SCHEMAS.keys

  APPLICATION_TYPES = EducationBenefitsSubmission.column_names.find_all do |column_name|
    column_name.include?('chapter')
  end.freeze

  validates(:form, :form_type, presence: true)
  validates(:form_type, inclusion: FORM_TYPES)
  validate(:form_matches_schema)
  validate(:form_must_be_string)

  has_one(:education_benefits_submission, inverse_of: :education_benefits_claim)

  attr_encrypted(:form, key: Settings.db_encryption_key)

  # initially only completed claims are allowed, later we can allow claims that dont have a submitted_at yet
  before_validation(:set_submitted_at, on: :create)
  before_save(:set_region)
  after_save(:create_education_benefits_submission)
  after_save(:update_education_benefits_submission_status)

  FORM_TYPES.each do |type|
    define_method("is_#{type}?") do
      form_type == type
    end
  end

  # For console access only, right now.
  def reprocess_at(region)
    key = region.to_sym
    unless EducationForm::EducationFacility::REGIONS.include?(key)
      raise "Invalid region. Must be one of #{EducationForm::EducationFacility::REGIONS.join(', ')}"
    end
    self.regional_processing_office = region
    self.processed_at = nil
    save
  end

  # This converts the form data into an OpenStruct object so that the template
  # rendering can be cleaner. Piping it through the JSON serializer was a quick
  # and easy way to deeply transform the object.
  def open_struct_form
    @application ||= JSON.parse(form, object_class: OpenStruct)
    @application.confirmation_number = confirmation_number

    generate_benefits_to_apply_to if is_1990?

    @application
  end

  def generate_benefits_to_apply_to
    selected_benefits = []
    APPLICATION_TYPES.each do |application_type|
      selected_benefits << application_type if @application.public_send(application_type)
    end
    selected_benefits = selected_benefits.join(', ')

    @application.toursOfDuty&.each do |tour|
      tour.benefitsToApplyTo = selected_benefits if tour.applyPeriodToSelected
    end
  end

  def self.unprocessed
    where(processed_at: nil)
  end

  def region
    EducationForm::EducationFacility.region_for(self)
  end

  def regional_office
    EducationForm::EducationFacility.regional_office_for(self)
  end

  def parsed_form
    @parsed_form ||= JSON.parse(form)
  end

  def confirmation_number
    "vets_gov_#{self.class.to_s.underscore}_#{id}"
  end

  def selected_benefits
    benefits = {}

    if is_1990?
      benefits = parsed_form.slice(*APPLICATION_TYPES)
    elsif is_1990e? || is_5490?
      benefit = parsed_form['benefit']
      benefits[benefit] = true if benefit.present?
    end

    benefits
  end

  private

  def create_education_benefits_submission
    if submitted_at.present? && submitted_at_was.nil? && education_benefits_submission.blank?
      opt = selected_benefits

      EducationBenefitsSubmission.create!(
        opt.merge(
          region: region,
          form_type: form_type,
          education_benefits_claim: self
        )
      )
    end
  end

  def update_education_benefits_submission_status
    if processed_at.present? && processed_at_was.nil?
      # old claims don't have an education benefits submission associated
      education_benefits_submission&.update_attributes!(status: 'processed')
    end
  end

  def form_is_string
    form.is_a?(String)
  end

  # if the form is a hash olive_branch will convert all the keys to underscore and break our json schema validation
  def form_must_be_string
    errors[:form] << 'must be a json string' unless form_is_string
  end

  def form_matches_schema
    return unless form_is_string
    return unless FORM_TYPES.include?(form_type)

    errors[:form].concat(JSON::Validator.fully_validate(FORM_SCHEMAS[form_type], parsed_form))
  end

  def set_submitted_at
    self.submitted_at = Time.zone.now
  end

  def set_region
    self.regional_processing_office ||= region.to_s
  end
end
