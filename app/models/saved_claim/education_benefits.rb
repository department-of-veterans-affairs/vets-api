# frozen_string_literal: true

class SavedClaim::EducationBenefits < SavedClaim
  has_one(:education_benefits_claim, foreign_key: 'saved_claim_id', inverse_of: :saved_claim)

  validates(:education_benefits_claim, presence: true)

  before_validation(:add_education_benefits_claim)

  # pulled from https://github.com/department-of-veterans-affairs/vets-website/blob/f27b8a5ffe4e2f9357d6c501c9a6a73dacdad0e1/src/applications/edu-benefits/utils/helpers.jsx#L100
  BENEFIT_TITLE_FOR_1990 = {
    'chapter30' => 'Montgomery GI Bill (MGIB or Chapter 30) Education Assistance Program',
    'chapter33' => 'Post-9/11 GI Bill (Chapter 33)',
    'chapter1606' => 'Montgomery GI Bill Selected Reserve (MGIB-SR or Chapter 1606) Educational Assistance Program',
    'chapter32' => 'Post-Vietnam Era Veterans’ Educational Assistance Program (VEAP or chapter 32)'
  }.freeze

  # pulled from https://github.com/department-of-veterans-affairs/vets-website/blob/f27b8a5ffe4e2f9357d6c501c9a6a73dacdad0e1/src/applications/edu-benefits/1990/helpers.jsx#L88
  BENEFIT_RELINQUISHED_TITLE_FOR_1990 = {
    'unknown' => 'I’m only eligible for the Post-9/11 GI Bill',
    'chapter30' => 'Montgomery GI Bill (MGIB-AD, Chapter 30)',
    'chapter1606' => 'Montgomery GI Bill Selected Reserve (MGIB-SR, Chapter 1606)',
    'chapter1607' => 'Reserve Educational Assistance Program (REAP, Chapter 1607)'
  }.freeze

  def self.form_class(form_type)
    raise 'Invalid form type' unless EducationBenefitsClaim::FORM_TYPES.include?(form_type)

    "SavedClaim::EducationBenefits::VA#{form_type}".constantize
  end

  def in_progress_form_id
    form_id
  end

  def after_submit(_user)
    parsed_form_data ||= JSON.parse(form)
    email = parsed_form_data['email']
    return if email.blank?

    case form_id
    when '22-5490'
      return unless Flipper.enabled?(:form5490_confirmation_email)

      send_5490_confirmation_email(parsed_form_data, email)
    when '22-1990'
      return unless Flipper.enabled?(:form1990_confirmation_email)

      send_1990_confirmation_email(parsed_form_data, email)
    end
  end

  private

  def send_5490_confirmation_email(parsed_form_data, email)
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
        'confirmation_number' => education_benefits_claim.confirmation_number,
        'regional_office_address' => regional_office_address
      }
    )
  end

  def send_1990_confirmation_email(parsed_form_data, email)
    benefit_relinquished = if parsed_form_data['benefitsRelinquished'].present?
                             "^__Benefits Relinquished:__\n^" \
                               "#{BENEFIT_RELINQUISHED_TITLE_FOR_1990[parsed_form_data['benefitsRelinquished']]}"
                           else
                             ''
                           end

    VANotify::EmailJob.perform_async(
      email,
      Settings.vanotify.services.va_gov.template_id.form1990_confirmation_email,
      {
        'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
        'benefits' => benefits_claimed1990(parsed_form_data),
        'benefit_relinquished' => benefit_relinquished,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
        'confirmation_number' => education_benefits_claim.confirmation_number,
        'regional_office_address' => regional_office_address
      }
    )
  end

  def benefits_claimed1990(parsed_form_data)
    %w[chapter30 chapter33 chapter1606 chapter32]
      .map { |benefit| parsed_form_data[benefit] ? BENEFIT_TITLE_FOR_1990[benefit] : nil }
      .compact
      .join("\n\n^")
  end

  def regional_office_address
    (_title, *address) = education_benefits_claim.regional_office.split("\n")
    address.join("\n")
  end

  def add_education_benefits_claim
    build_education_benefits_claim if education_benefits_claim.nil?
  end
end
