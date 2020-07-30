# frozen_string_literal: true

class SchoolCertifyingOfficialsMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?

    applicant = SavedClaim::EducationBenefits::VA10203.last&.open_struct_form
    ga_client_id = nil
    SchoolCertifyingOfficialsMailer.build(applicant, recipients(params[:facility_code]), ga_client_id) if applicant.present?
  end

  private

  def recipients(facility_code)
    institution = GIDSRedis.new.get_institution_details({ id: facility_code })[:data][:attributes]
    return [] unless institution.present?

    scos = institution[:versioned_school_certifying_officials]
    EducationForm::SendSCOEmail.sco_emails(scos)
  end
end
