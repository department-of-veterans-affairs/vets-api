class SchoolCertifyingOfficialsMailerPreview < ActionMailer::Preview
  def build
    applicant = SavedClaim::EducationBenefits::VA10203.first.open_struct_form
    recipients = []
    ga_client_id = nil
    SchoolCertifyingOfficialsMailer.build(applicant, recipients, ga_client_id)
  end
end