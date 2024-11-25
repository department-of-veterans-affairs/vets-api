# frozen_string_literal: true

require 'va_profile/demographics/service'

module VA0873
  FORM_ID = '0873'

  class FormPersonalInformation
    include Virtus.model

    attribute :first, String
    attribute :middle, String
    attribute :last, String
    attribute :suffix, String
    attribute :preferred_name, String
    attribute :service_number, String
  end

  class FormAvaProfile
    include Virtus.model

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

  def initialize_personal_information
    service_number = profile.is_a?(Hash) ? profile : profile.service_number

    payload = user.full_name_normalized.merge(preferred_name:, service_number:)

    VA0873::FormPersonalInformation.new(payload)
  rescue => e
    log_exception_to_sentry(e, {}, prefill: :personal_information)
    {}
  end

  def initialize_ava_profile
    school_name = nil

    unless profile.school_facility_code.nil?
      school = GIDSRedis.new.get_institution_details_v0(id: profile.school_facility_code)
      school_name = school[:data][:attributes][:name]
    end

    payload = {
      school_facility_code: profile.school_facility_code,
      school_name:,
      business_phone: profile.business_phone,
      business_email: profile.business_email
    }

    VA0873::FormAvaProfile.new(payload)
  rescue => e
    log_exception_to_sentry(e, {}, prefill: :personal_information)
    {}
  end

  def preferred_name
    VAProfile::Demographics::Service.new(user).get_demographics.demographics.preferred_name.text
  rescue => e
    log_exception_to_sentry(e, {}, prefill: :personal_information)
    {}
  end

  def profile
    AskVAApi::Profile::Retriever.new(icn: user.icn).call
  rescue => e
    log_exception_to_sentry(e, {}, prefill: :personal_information)
    {}
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/your-personal-information'
    }
  end
end
