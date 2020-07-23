# frozen_string_literal: true

class SchoolCertifyingOfficialsMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?

    applicant = SavedClaim::EducationBenefits::VA10203.last&.open_struct_form
    recipients = []
    ga_client_id = nil
    SchoolCertifyingOfficialsMailer.build(applicant, recipients, ga_client_id) unless applicant.blank?
  end
end
