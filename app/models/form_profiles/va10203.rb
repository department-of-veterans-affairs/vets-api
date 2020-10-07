# frozen_string_literal: true

require 'evss/gi_bill_status/service'

module VA10203
  FORM_ID = '22-10203'

  class FormInstitutionInfo
    include Virtus.model

    attribute :name, String
    attribute :city, String
    attribute :state, String
    attribute :country, String
  end

  class FormEntitlementInformation
    include Virtus.model

    attribute :months, Integer
    attribute :days, Integer
  end
end

class FormProfiles::VA10203 < FormProfile
  attribute :remaining_entitlement, VA10203::FormEntitlementInformation
  attribute :school_information, VA10203::FormInstitutionInfo

  def prefill
    authorized = user.authorize :evss, :access?

    if Flipper.enabled?(:stem_sco_email, user) && authorized
      gi_bill_status = get_gi_bill_status
      @remaining_entitlement = initialize_entitlement_information(gi_bill_status)
      @school_information = initialize_school_information(gi_bill_status)
    else
      @remaining_entitlement = {}
      @school_information = {}
    end

    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end

  private

  def get_gi_bill_status
    service = EVSS::GiBillStatus::Service.new(user)
    service.get_gi_bill_status
  rescue => e
    Rails.logger.error "Failed to retrieve GiBillStatus data: #{e.message}"
    {}
  end

  def initialize_entitlement_information(gi_bill_status)
    return {} if gi_bill_status == {} || gi_bill_status.remaining_entitlement.blank?

    VA10203::FormEntitlementInformation.new(
      months: gi_bill_status.remaining_entitlement.months,
      days: gi_bill_status.remaining_entitlement.days
    )
  end

  def initialize_school_information(gi_bill_status)
    return {} if gi_bill_status == {}

    most_recent = gi_bill_status.enrollments.max_by(&:begin_date)

    return {} if most_recent.blank?

    service = GIDSRedis.new
    profile_response = service.get_institution_details({ id: most_recent.facility_code })

    VA10203::FormInstitutionInfo.new(
      name: profile_response[:data][:attributes][:name],
      city: profile_response[:data][:attributes][:city],
      state: profile_response[:data][:attributes][:state],
      country: profile_response[:data][:attributes][:country]
    )
  rescue => e
    Rails.logger.error "Failed to retrieve GIDS data: #{e.message}"
    {}
  end
end
