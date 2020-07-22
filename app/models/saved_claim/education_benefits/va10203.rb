# frozen_string_literal: true

include EducationForm

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10203')

  def after_submit(user)
    return unless Flipper.enabled?(:edu_benefits_stem_scholarship)

    authorized = user.authorize :evss, :access?
    email_sent(false)

    if authorized
      @gi_bill_status = get_gi_bill_status(user)

      unless @gi_bill_status.remaining_entitlement&.blank?
        @facility_code = get_facility_code

        unless @facility_code.blank?
          @institution = get_institution

          unless more_than_six_months || @institution.blank? || school_changed?
            send_sco_email
          end
        end
      end
    end

    save
  end

  private

  def email_sent(sco_email_sent)
    application = parsed_form
    application["scoEmailSent"] = sco_email_sent
    self.form = JSON.generate(application)
  end

  def get_gi_bill_status(user)
    service = EVSS::GiBillStatus::Service.new(user)
    service.get_gi_bill_status
  rescue => e
    Rails.logger.error "Failed to retrieve GiBillStatus data: #{e.message}"
    {}
  end

  def get_facility_code
    most_recent = @gi_bill_status.enrollments.max_by(&:begin_date)

    return {} if most_recent.blank?
    most_recent.facility_code
  end

  def get_institution
    GIDSRedis.new.get_institution_details({id: @facility_code})[:data][:attributes]
  end

  def more_than_six_months
    months = @gi_bill_status.remaining_entitlement.months
    days = @gi_bill_status.remaining_entitlement.days

    ((months * 30) + days ) > 180
  end

  def school_changed?
    application = parsed_form
    form_school_name = application["schoolName"]
    form_school_city = application["schoolCity"]
    form_school_state = application["schoolState"]

    prefill_name = @institution[:name]
    prefill_city = @institution[:city]
    prefill_state = @institution[:state]

    form_school_name != prefill_name ||
        form_school_city != prefill_city ||
        form_school_state != prefill_state
  end

  def send_sco_email
    return if FeatureFlipper.send_email?

    recipients = []
    application = parsed_form

    scos = @institution[:versioned_school_certifying_officials]
    primary = scos.find{ |sco| sco[:priority] == 'Primary' && sco[:email].present?}
    secondary = scos.find{ |sco| sco[:priority] == 'Secondary' && sco[:email].present?}

    unless primary.blank? && secondary.blank?
      recipients.push(primary[:email]) if primary.present?
      recipients.push(secondary[:email]) if secondary.present?

      SchoolCertifyingOfficialsMailer.build(recipients, nil, application["email"]).deliver_now
      email_sent(true)
    end
  end

end
