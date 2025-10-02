# frozen_string_literal: true

require 'lighthouse/benefits_education/service'
require 'feature_flipper'

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10203')

  class Submit10203Error < StandardError
  end

  def after_submit(user)
    @user = user
    if @user.present?
      @gi_bill_status = get_gi_bill_status
      create_stem_automated_decision
    end

    email_sent(false)

    send_confirmation_email if Flipper.enabled?(:form21_10203_confirmation_email)

    if @user.present? && FeatureFlipper.send_email?
      education_benefits_claim.education_stem_automated_decision.update(confirmation_email_sent_at: Time.zone.now)

      authorized = @user.authorize(:evss, :access?)

      if authorized
        EducationForm::SendSchoolCertifyingOfficialsEmail.perform_async(id, less_than_six_months?,
                                                                        get_facility_code)
      end
    end
  end

  def create_stem_automated_decision
    logger.info "EDIPI available for submit STEM claim id=#{education_benefits_claim.id}: #{@user.edipi.present?}"

    education_benefits_claim.build_education_stem_automated_decision(
      user_uuid: @user.uuid,
      user_account: @user.user_account,
      auth_headers_json: EVSS::AuthHeaders.new(@user).to_h.to_json,
      remaining_entitlement:
    ).save
  end

  def email_sent(sco_email_sent)
    update_form('scoEmailSent', sco_email_sent)
    save
  end

  private

  def get_gi_bill_status
    service = BenefitsEducation::Service.new(@user.icn)
    service.get_gi_bill_status
  rescue => e
    Rails.logger.error "Failed to retrieve GiBillStatus data: #{e.message}"
    {}
  end

  def get_facility_code
    return {} if @gi_bill_status.blank? || @gi_bill_status.enrollments.blank?

    most_recent = @gi_bill_status.enrollments.max_by(&:begin_date)

    return {} if most_recent.blank?

    most_recent.facility_code
  end

  def remaining_entitlement
    return nil if @gi_bill_status.blank? || @gi_bill_status.remaining_entitlement.blank?

    months = @gi_bill_status.remaining_entitlement.months
    days = @gi_bill_status.remaining_entitlement.days

    ((months * 30) + days)
  end

  def less_than_six_months?
    return false if remaining_entitlement.blank?

    remaining_entitlement <= 180
  end

  def send_confirmation_email
    parsed_form = JSON.parse(form)
    email = parsed_form['email']
    return if email.blank?

    if Flipper.enabled?(:form1995_confirmation_email_with_silent_failure_processing)
      # this method is in the parent class
      send_education_benefits_confirmation_email(email, parsed_form, {})
    else
      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.form21_10203_confirmation_email,
        {
          'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => education_benefits_claim.confirmation_number,
          'regional_office_address' => regional_office_address
        }
      )
    end
  end

  def template_id
    Settings.vanotify.services.va_gov.template_id.form21_10203_confirmation_email
  end
end
