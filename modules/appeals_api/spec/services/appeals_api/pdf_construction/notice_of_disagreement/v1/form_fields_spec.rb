# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::NoticeOfDisagreement::V1::FormFields do
  let(:form_fields) { described_class.new }

  describe '#veteran_name' do
    it { expect(form_fields.veteran_name).to eq('F[0].Page_1[0].VeteransFirstName[0]') }
  end

  describe '#veteran_ssn' do
    it do
      expect(form_fields.veteran_ssn)
        .to eq('F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]')
    end
  end

  describe '#veteran_file_number' do
    it { expect(form_fields.veteran_file_number).to eq('F[0].Page_1[0].VAFileNumber[0]') }
  end

  describe '#veteran_dob' do
    it { expect(form_fields.veteran_dob).to eq('F[0].Page_1[0].DateSigned[0]') }
  end

  describe '#mailing_address' do
    it do
      expect(form_fields.mailing_address)
        .to eq('F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]')
    end
  end

  describe '#homeless' do
    it { expect(form_fields.homeless).to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[0]') }
  end

  describe '#preferred_phone' do
    it { expect(form_fields.preferred_phone).to eq('F[0].Page_1[0].PreferredPhoneNumber[0]') }
  end

  describe '#direct_review' do
    it { expect(form_fields.direct_review).to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[1]') }
  end

  describe '#evidence_submission' do
    it do
      expect(form_fields.evidence_submission)
        .to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[2]')
    end
  end

  describe '#hearing' do
    it { expect(form_fields.hearing).to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[3]') }
  end

  describe '#extra_contestable_issues' do
    it do
      expect(form_fields.extra_contestable_issues)
        .to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[4]')
    end
  end

  describe '#soc_opt_in' do
    it { expect(form_fields.soc_opt_in).to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[5]') }
  end

  describe '#signature' do
    it { expect(form_fields.signature).to eq('F[0].Page_1[0].SignatureOfClaimant_AuthorizedRepresentative[0]') }
  end

  describe '#date_signed' do
    it { expect(form_fields.date_signed).to eq('F[0].Page_1[0].DateSigned[2]') }
  end

  describe '#issue_table_decision_date' do
    it { expect(form_fields.issue_table_decision_date(6)).to eq('F[0].Page_1[0].Percentage2[6]') }
  end
end
