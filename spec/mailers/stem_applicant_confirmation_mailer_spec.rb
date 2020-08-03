# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StemApplicantConfirmationMailer, type: [:mailer] do
  subject do
    described_class.build(education_benefits_claim, ga_client_id).deliver_now
  end

  let(:education_benefits_claim) { build(:education_benefits_claim_10203, created_at: Time.zone.local(2020)) }
  let(:applicant) { education_benefits_claim.open_struct_form }
  let(:ga_client_id) { '123456543' }

  describe '#build' do
    it 'includes subject' do
      expect(subject.subject).to eq(StemApplicantConfirmationMailer::SUBJECT)
    end

    it 'includes recipients' do
      expect(subject.to).to eq([applicant.email])
    end

    context 'applicant information in email body' do
      it 'includes veteran name' do
        name = applicant.veteranFullName
        first_and_last_name = "#{name.first} #{name.last}"
        expect(subject.body.raw_source).to include("for #{first_and_last_name}")
      end
      it 'includes confirmation number' do
        expect(subject.body.raw_source).to include("Confirmation number #{applicant.confirmation_number}")
      end
      it 'includes date received' do
        date_received = education_benefits_claim.created_at.strftime('%b %d, %Y')
        expect(subject.body.raw_source).to include("Date received #{date_received}")
      end
    end

    context 'when sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).twice.and_return(true)
      end

      it 'includes recipients' do
        described_class.build(education_benefits_claim, ga_client_id).deliver_now
        expect(subject.bcc).to eq(SchoolCertifyingOfficialsMailer::STAGING_RECIPIENTS)
      end
    end
  end
end
