# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SchoolCertifyingOfficialsMailer, type: [:mailer] do
  subject do
    described_class.build(applicant, recipients, ga_client_id).deliver_now
  end

  let(:education_benefits_claim) { build(:va10203) }
  let(:applicant) { education_benefits_claim.open_struct_form }
  let(:recipients) { ['foo@example.com'] }
  let(:ga_client_id) { '123456543' }

  describe '#build' do
    it 'includes subject' do
      expect(subject.subject).to eq(SchoolCertifyingOfficialsMailer::SUBJECT)
    end

    it 'includes recipients' do
      expect(subject.to).to eq(recipients)
    end

    context 'applicant information in email body' do
      it 'includes veteran full name' do
        name = applicant.veteranFullName
        first_initial_last_name = "#{name.first[0, 1]} #{name.last}"
        expect(subject.body.raw_source).to include("Student's name: #{first_initial_last_name}")
      end
      it 'includes school email address' do
        expect(subject.body.raw_source).to include("Student's school email address: #{applicant.schoolEmailAddress}")
      end
      it 'includes school student id' do
        expect(subject.body.raw_source).to include("Student's school ID number: #{applicant.schoolStudentId}")
      end
    end
  end
end
