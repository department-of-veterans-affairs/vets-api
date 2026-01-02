# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StemApplicantScoMailer, type: [:mailer] do
  subject do
    described_class.build(education_benefits_claim.id, ga_client_id).deliver_now
  end

  let(:education_benefits_claim) { create(:va10203) }
  let(:applicant) { education_benefits_claim.open_struct_form }
  let(:ga_client_id) { '123456543' }

  describe '#build' do
    it 'includes subject' do
      expect(subject.subject).to eq(StemApplicantScoMailer::SUBJECT)
    end

    it 'includes applicant email' do
      expect(subject.to).to eq([applicant.email])
    end

    context 'applicant information in email body' do
      it 'includes veteran first and last name' do
        name = applicant.veteranFullName
        first_initial_last_name = "#{name.first} #{name.last}"
        expect(subject.body.raw_source).to include("Dear #{first_initial_last_name},")
      end

      it 'includes school name' do
        expect(subject.body.raw_source).to include(
          "We sent the email below to the School Certifying Official (SCO) at #{applicant.schoolName} to gather"
        )
      end
    end
  end
end
