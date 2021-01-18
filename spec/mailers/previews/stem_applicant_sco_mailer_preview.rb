# frozen_string_literal: true

class StemApplicantScoMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?

    applicant = SavedClaim::EducationBenefits::VA10203.last&.open_struct_form
    ga_client_id = nil
    StemApplicantScoMailer.build(applicant || fake_applicant, ga_client_id)
  end

  private

  def fake_applicant
    name = OpenStruct.new({
                            first: 'Test',
                            last: 'McTestyFace'
                          })
    OpenStruct.new({
                     email: 'test@sample.com',
                     schoolEmailAddress: 'test@sample.edu',
                     schoolStudentId: '123',
                     schoolName: 'College of University',
                     veteranFullName: name
                   })
  end
end
