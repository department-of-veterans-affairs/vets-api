# frozen_string_literal: true

class EducationBenefitsClaim < ApplicationRecord
  FORM_TYPES = %w[1990 1995 1990e 5490 5495 1990n 0993 0994 10203 1990s].freeze

  APPLICATION_TYPES = %w[
    chapter33
    chapter1607
    chapter1606
    chapter32
    chapter35
    transfer_of_entitlement
    vettec
    chapter30
    vrrap
  ].freeze

  belongs_to(:saved_claim, class_name: 'SavedClaim::EducationBenefits', inverse_of: :education_benefits_claim)

  has_one(:education_benefits_submission, inverse_of: :education_benefits_claim)
  has_one(:education_stem_automated_decision, inverse_of: :education_benefits_claim, dependent: :destroy)

  delegate(:parsed_form, to: :saved_claim)
  delegate(:form, to: :saved_claim)

  before_save(:set_region)
  after_create(:create_education_benefits_submission)
  after_save(:update_education_benefits_submission_status)

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

  def confirmation_number
    "V-EBC-#{id}"
  end

  FORM_TYPES.each do |type|
    define_method("is_#{type}?") do
      form_type == type
    end
  end

  def form_type
    saved_claim.form_id.gsub('22-', '').downcase
  end

  # This converts the form data into an OpenStruct object so that the template
  # rendering can be cleaner. Piping it through the JSON serializer was a quick
  # and easy way to deeply transform the object.
  def open_struct_form
    @application ||= lambda do
      @application = saved_claim.open_struct_form
      @application.confirmation_number = confirmation_number

      transform_form

      @application
    end.call
  end

  def transform_form
    generate_benefits_to_apply_to if is_1990?
    copy_from_previous_benefits if is_5490?
  end

  def copy_from_previous_benefits
    if @application.currentSameAsPrevious
      previous_benefits = @application.previousBenefits

      %w[veteranFullName vaFileNumber veteranSocialSecurityNumber].each do |attr|
        @application.public_send("#{attr}=", previous_benefits.public_send(attr))
      end
    end
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

  def selected_benefits
    benefits = {}

    case form_type
    when '1990'
      benefits = parsed_form.slice(*APPLICATION_TYPES)
    when '1990n'
      return benefits
    when '0994'
      benefits['vettec'] = true
    when '1990s'
      benefits['vrrap'] = true
    else
      benefit = parsed_form['benefit']&.underscore
      benefits[benefit] = true if benefit.present?
    end

    benefits
  end

  def self.form_headers(form_types = FORM_TYPES)
    form_types.map { |t| "22-#{t}" }.freeze
  end

  private

  def create_education_benefits_submission
    opt = selected_benefits

    EducationBenefitsSubmission.create!(
      opt.merge(
        region:,
        form_type:,
        education_benefits_claim: self
      )
    )
  end

  def update_education_benefits_submission_status
    if processed_at.present? && attribute_before_last_save(:processed).nil?
      # old claims don't have an education benefits submission associated
      education_benefits_submission&.update!(status: 'processed')
    end
  end

  def set_region
    self.regional_processing_office ||= region.to_s
  end
end
