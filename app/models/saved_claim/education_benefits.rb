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

  def after_submit(_user)
    case form_id
    when '22-5490'
      return unless Flipper.enabled?(:form5490_confirmation_email)

      send_5490_confirmation_email
    end
  end

  private

  def parsed_form_data
    @parsed_form_data ||= JSON.parse(form)
  end

  def send_5490_confirmation_email
    email = parsed_form_data['email']
    return if email.blank?

    benefit = case parsed_form_data['benefit']
              when 'chapter35'
                'Survivors’ and Dependents’ Educational Assistance (DEA, Chapter 35)'
              when 'chapter33'
                'The Fry Scholarship (Chapter 33)'
              end

    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form5490_confirmation_email,
      {
        'first_name' => parsed_form.dig('relativeFullName', 'first')&.upcase.presence,
        'benefit' => benefit,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number
      }
    )
  end

  def add_education_benefits_claim
    build_education_benefits_claim if education_benefits_claim.nil?
  end
end
