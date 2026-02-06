# frozen_string_literal: true

class SavedClaim::EducationBenefits < SavedClaim
  has_one(:education_benefits_claim, foreign_key: 'saved_claim_id', inverse_of: :saved_claim, dependent: :destroy)

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

  def requires_authenticated_user?
    false
  end

  def retention_period
    nil
  end

  private

  def regional_office_address
    (_title, *address) = education_benefits_claim.regional_office.split("\n")
    address.join("\n")
  end

  def add_education_benefits_claim
    build_education_benefits_claim if education_benefits_claim.nil?
  end

  # most forms use regional_office_address so default to true. For forms that don't, set regional_office: false
  # rubocop:disable Metrics/MethodLength
  def send_education_benefits_confirmation_email(email, parsed_form_data, template_params = {}, regional_office: true)
    form_number = self.class.name.split('::').last.downcase.gsub('va', '')

    # Base parameters that all forms have
    base_params = {
      'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
      'confirmation_number' => education_benefits_claim.confirmation_number
    }

    # Add regional office address if the form supports it
    base_params['regional_office_address'] = regional_office_address if regional_office

    # Add first name - most forms use this pattern
    first_name_key = determine_first_name_key
    base_params['first_name'] = parsed_form_data.dig(first_name_key, 'first')&.upcase.presence

    # Merge with form-specific parameters
    all_params = base_params.merge(template_params)

    # Build callback options
    callback_options = build_callback_options(form_number)

    begin
      VANotify::EmailJob.perform_async(
        email,
        template_id,
        all_params,
        Settings.vanotify.services.va_gov.api_key,
        callback_options
      )
    rescue => e
      method_name = 'send_confirmation_email'
      Rails.logger.error "#{self.class.name}##{method_name}: Failed to queue confirmation email: #{e.message}"
    end
  end
  # rubocop:enable Metrics/MethodLength

  def determine_first_name_key
    case self.class.name.split('::').last
    when 'VA0994', 'VA5490', 'VA5495'
      'relativeFullName'
    when 'VA10297'
      'applicantFullName'
    else
      'veteranFullName'
    end
  end

  def build_callback_options(form_number)
    # based on my understanding of modules/va_notify/lib/default_callback.rb &
    # lib/veteran_facing_services/adr/vanotify_default_callback_concerns.md,
    # we should be using someting other than error for the notification_type

    {
      callback_metadata: {
        notification_type: 'confirmation',
        form_number: "22-#{form_number}",
        statsd_tags: {
          service: "submit-#{form_number}-form",
          function: "form_#{form_number}_failure_confirmation_email_sending"
        }
      }
    }
  end

  def template_id
    raise NotImplementedError, "#{self.class.name} must implement template_id method"
  end
end
