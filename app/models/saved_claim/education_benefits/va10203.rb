# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10203')

  def after_submit(user)
    authorized = user.authorize :evss, :access?

    if authorized
      # gi_bill_status = get_gi_bill_status(user)
      # remaining_entitlement = initialize_entitlement_information(gi_bill_status)
      # facility_code = facility_code(gi_bill_status)

      email_sent
      save
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

  def facility_code(gi_bill_status)
    return {} if gi_bill_status == {}

    most_recent = gi_bill_status.enrollments.max_by(&:begin_date)

    return {} if most_recent.blank?
    most_recent.facility_code
  end

  def email_sent
    application = parsed_form
    application["scoEmailSent"] = true
    self.form = JSON.generate(application)
  end
end
