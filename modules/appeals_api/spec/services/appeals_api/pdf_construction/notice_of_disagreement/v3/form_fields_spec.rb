# frozen_string_literal: true

require_relative '../v2/form_fields_spec'

describe AppealsApi::PdfConstruction::NoticeOfDisagreement::V3::FormFields do
  let(:form_fields) { described_class.new }

  describe '#veteran_file_number' do
    it do
      expect(form_fields.veteran_file_number)
        .to eq('F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]')
    end
  end

  describe '#veteran_dob' do
    it { expect(form_fields.veteran_dob).to eq('F[0].Page_1[0].DateSigned[0]') }
  end

  describe '#claimant_dob' do
    it { expect(form_fields.claimant_dob).to eq('F[0].Page_1[0].DateSigned[1]') }
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

  describe '#central_office_hearing' do
    it {
      expect(form_fields.central_office_hearing)
        .to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[4]')
    }
  end

  describe '#video_conference_hearing' do
    it {
      expect(form_fields.video_conference_hearing)
        .to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[5]')
    }
  end

  describe '#virtual_tele_hearing' do
    it {
      expect(form_fields.virtual_tele_hearing).to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[6]')
    }
  end

  describe '#requesting_extension' do
    it {
      expect(form_fields.requesting_extension).to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[7]')
    }
  end

  describe '#appealing_vha_denial' do
    it {
      expect(form_fields.appealing_vha_denial).to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[8]')
    }
  end

  describe '#extra_contestable_issues' do
    it do
      expect(form_fields.extra_contestable_issues)
        .to eq('F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[9]')
    end
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
