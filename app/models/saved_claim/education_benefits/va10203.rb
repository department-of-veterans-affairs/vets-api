# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10203')

  after_save(:notify_school_contact_officials)

  def notify_school_contact_officials
    authorized = user.authorize :evss, :access?

    if authorized
      gi_bill_status = get_gi_bill_status(user)
      @remaining_entitlement = initialize_entitlement_information(gi_bill_status)
      @school_information = initialize_school_information(gi_bill_status)
    else
      @remaining_entitlement = {}
      @school_information = {}
    end
  end

  private

  def get_gi_bill_status(user)
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

    service = GI::Client.new
    profile_response = service.get_institution_details({ id: most_recent.facility_code })

    VA10203::FormInstitutionInfo.new(
        name: profile_response.body[:data][:attributes][:name],
        city: profile_response.body[:data][:attributes][:city],
        state: profile_response.body[:data][:attributes][:state]
    )
  rescue => e
    Rails.logger.error "Failed to retrieve GIDS data: #{e.message}"
    {}
  end

end
