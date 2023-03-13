# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::SupplementalClaim::V2::FormFields do
  # rubocop:disable Layout/LineLength
  let(:form_fields) { described_class.new }

  describe '#veteran_middle_initial' do
    it { expect(form_fields.veteran_middle_initial).to eq 'form1[0].#subform[2].VeteransMiddleInitial1[0]' }
  end

  describe '#veteran_ssn_first_three' do
    it {
      expect(form_fields.veteran_ssn_first_three).to eq 'form1[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]'
    }
  end

  describe '#veteran_ssn_middle_two' do
    it {
      expect(form_fields.veteran_ssn_middle_two).to eq 'form1[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]'
    }
  end

  describe '#veteran_ssn_last_four' do
    it {
      expect(form_fields.veteran_ssn_last_four).to eq 'form1[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]'
    }
  end

  describe '#file_number' do
    it { expect(form_fields.file_number).to eq 'form1[0].#subform[2].VAFileNumber[0]' }
  end

  describe '#veteran_dob_month' do
    it { expect(form_fields.veteran_dob_month).to eq 'form1[0].#subform[2].DOBmonth[0]' }
  end

  describe '#veteran_dob_day' do
    it { expect(form_fields.veteran_dob_day).to eq 'form1[0].#subform[2].DOBday[0]' }
  end

  describe '#veteran_dob_year' do
    it { expect(form_fields.veteran_dob_year).to eq 'form1[0].#subform[2].DOByear[0]' }
  end

  describe '#veteran_service_number' do
    it { expect(form_fields.veteran_service_number).to eq 'form1[0].#subform[2].VeteransServiceNumber[0]' }
  end

  describe '#insurance_policy_number' do
    it { expect(form_fields.insurance_policy_number).to eq 'form1[0].#subform[2].InsurancePolicyNumber[0]' }
  end

  describe '#mailing_address_state' do
    it {
      expect(
        form_fields.mailing_address_state
      ).to eq 'form1[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]'
    }
  end

  describe '#mailing_address_country' do
    it {
      expect(form_fields.mailing_address_country).to eq 'form1[0].#subform[2].CurrentMailingAddress_Country[0]'
    }
  end

  describe '#signing_appellant_phone' do
    it { expect(form_fields.phone).to eq 'form1[0].#subform[2].TELEPHONE[0]' }
  end

  describe '#signing_appellant_phone_area_code' do
    it {
      expect(form_fields.signing_appellant_phone_area_code).to eq 'form1[0].#subform[2].Daytime_Phone_Number_Area_Code[0]'
    }
  end

  describe '#signing_appellant_phone_prefix' do
    it {
      expect(form_fields.signing_appellant_phone_prefix).to eq 'form1[0].#subform[2].Daytime_Phone_Middle_Three_Numbers[0]'
    }
  end

  describe '#signing_appellant_phone_line_number' do
    it {
      expect(form_fields.signing_appellant_phone_line_number).to eq 'form1[0].#subform[2].Daytime_Phone_Last_Four_Numbers[0]'
    }
  end

  describe '#signing_appellant_international_phone' do
    it {
      expect(form_fields.signing_appellant_international_phone).to eq 'form1[0].#subform[2].International_Telephone_Number_If_Applicable[0]'
    }
  end

  describe '#claimant_type' do
    it { expect(form_fields.claimant_type).to eq 'form1[0].#subform[2].RadioButtonList[1]' }
  end

  describe '#benefit_type' do
    it { expect(form_fields.benefit_type).to eq 'form1[0].#subform[2].RadioButtonList[0]' }
  end

  describe '#soc_ssoc_opt_in' do
    it { expect(form_fields.soc_ssoc_opt_in).to eq 'form1[0].#subform[2].RadioButtonList[2]' }
  end

  describe '#form_5103_notice_acknowledged' do
    it { expect(form_fields.form_5103_notice_acknowledged).to eq 'form1[0].#subform[3].TIME1230TO2PM[0]' }
  end

  describe '#date_signed' do
    it { expect(form_fields.date_signed).to eq 'form1[0].#subform[3].DATESIGNED[0]' }
  end
  # rubocop:enable Layout/LineLength
end
