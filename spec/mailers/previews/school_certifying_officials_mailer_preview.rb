# frozen_string_literal: true

class SchoolCertifyingOfficialsMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?

    applicant = SavedClaim::EducationBenefits::VA10203.last&.open_struct_form
    ga_client_id = nil
    emails = recipients(params[:facility_code])
    SchoolCertifyingOfficialsMailer.build(applicant || fake_applicant, emails, ga_client_id)
  end

  private

  def recipients(facility_code)
    return [] if facility_code.blank?

    institution = GIDSRedis.new.get_institution_details({ id: facility_code })[:data][:attributes]
    return [] if institution.blank?

    scos = institution[:versioned_school_certifying_officials]
    EducationForm::SendSCOEmail.sco_emails(scos)
  end

  def fake_applicant
    name = OpenStruct.new({
                            first: 'T',
                            last: 'McTestyFace'
                          })
    OpenStruct.new({
                     email: 'test@sample.com',
                     schoolEmailAddress: nil,
                     schoolStudentId: nil,
                     veteranFullName: name
                   })
  end
end
