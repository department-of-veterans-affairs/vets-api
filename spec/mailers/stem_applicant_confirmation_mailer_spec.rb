# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StemApplicantConfirmationMailer, type: [:mailer] do
  subject do
    described_class.build(saved_claim, ga_client_id).deliver_now
  end

  let(:saved_claim) do
    claim = build(:va10203)
    claim.save
    claim
  end
  let(:applicant) { saved_claim.open_struct_form }
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
        date_received = saved_claim.created_at.strftime('%b %d, %Y')
        expect(subject.body.raw_source).to include("Date received #{date_received}")
      end

      it 'includes Eastern RPO name' do
        expect(subject.body.raw_source).to include(EducationForm::EducationFacility::EMAIL_NAMES[:eastern])
      end

      it 'includes Eastern RPO address' do
        expect(subject.body.raw_source).to include(EducationForm::EducationFacility::ADDRESSES[:eastern][0])
      end

      it 'includes Eastern RPO address city, state, and zip' do
        expect(subject.body.raw_source).to include(EducationForm::EducationFacility::ADDRESSES[:eastern][1])
      end
    end
  end
end
