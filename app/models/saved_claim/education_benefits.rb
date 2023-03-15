# frozen_string_literal: true

class SavedClaim::EducationBenefits < SavedClaim
  has_one(:education_benefits_claim, foreign_key: 'saved_claim_id', inverse_of: :saved_claim)

  validates(:education_benefits_claim, presence: true)

  before_validation(:add_education_benefits_claim)

  def self.form_class(form_type)
    raise 'Invalid form type' unless EducationBenefitsClaim::FORM_TYPES.include?(form_type)

    "SavedClaim::EducationBenefits::VA#{form_type}".constantize
  end

  def in_progress_form_id
    form_id
  end

  def after_submit(user); end

  private

  def regional_office_address
    (_title, *address) = education_benefits_claim.regional_office.split("\n")
    address.join("\n")
  end

  def add_education_benefits_claim
    build_education_benefits_claim if education_benefits_claim.nil?
  end
end
