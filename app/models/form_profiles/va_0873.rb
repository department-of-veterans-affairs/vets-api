# frozen_string_literal: true

require 'va_profile/demographics/service'

module VA0873
  FORM_ID = '0873'

  class FormPersonalInformation
    include Vets::Model

    attribute :first, String
    attribute :middle, String
    attribute :last, String
    attribute :suffix, String
    attribute :preferred_name, String
    attribute :service_number, String
    attribute :work_phone, String
  end

  class FormAvaProfile
    include Vets::Model

    attribute :school_facility_code, String
    attribute :school_name, String
    attribute :business_phone, String
    attribute :business_email, String
  end
end

class FormProfiles::VA0873 < FormProfile
  attribute :personal_information, VA0873::FormPersonalInformation
  attribute :ava_profile, VA0873::FormAvaProfile

  def prefill
    @personal_information = initialize_personal_information
    @ava_profile = initialize_ava_profile
    super
  end

  private

  # Initializes the personal information for the form with proper error handling
  def initialize_personal_information
    service_number = extract_service_number
    work_phone     = format_work_phone

    payload = user.full_name_normalized.merge(
      preferred_name:,
      service_number:,
      work_phone:
    )

    VA0873::FormPersonalInformation.new(payload)
  rescue => e
    handle_exception(e, :personal_information)
  end

  # Initializes the AVA profile for the form, retrieving school details if available
  def initialize_ava_profile
    school_name = fetch_school_name(profile.school_facility_code)

    payload = {
      school_facility_code: profile.school_facility_code,
      school_name:,
      business_phone: profile.business_phone,
      business_email: profile.business_email
    }

    VA0873::FormAvaProfile.new(payload)
  rescue => e
    handle_exception(e, :ava_profile)
  end

  # Retrieves the preferred name for the user
  def preferred_name
    VAProfile::Demographics::Service.new(user).get_demographics.demographics.preferred_name.text
  rescue => e
    handle_exception(e, :preferred_name)
  end

  # Retrieves the profile from the AskVAApi service
  def profile
    @profile ||= AskVAApi::Profile::Retriever.new(icn: user.icn).call
  rescue => e
    handle_exception(e, :profile)
  end

  # Retrieves the school name based on the facility code if available
  def fetch_school_name(facility_code)
    return nil if facility_code.nil?

    school = GIDSRedis.new.get_institution_details_v0(id: facility_code)
    school.dig(:data, :attributes, :name)
  rescue => e
    handle_exception(e, :school_name)
  end

  # Logs the exception to Sentry and returns an empty object as a fallback
  def handle_exception(exception, context)
    log_exception_to_sentry(exception, {}, prefill: context)
    {}
  end

  def extract_service_number
    profile.is_a?(Hash) ? profile[:service_number] : profile&.service_number
  end

  def format_work_phone
    phone = user&.vet360_contact_info&.work_phone
    return nil unless phone

    [
      phone.country_code,
      phone.area_code,
      phone.phone_number,
      phone.extension
    ].compact.join
  end

  # Metadata for the form
  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/your-personal-information'
    }
  end
end
