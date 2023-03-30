# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::SupplementalClaim::V3::FormData do
  let(:created_at) { '2023-02-03' }
  let(:supplemental_claim) { build(:extra_supplemental_claim, created_at:) }
  let(:form_data) { described_class.new(supplemental_claim) }

  {
    veteran_middle_initial: 'ø',
    veteran_ssn_first_three: '123',
    veteran_ssn_middle_two: '45',
    veteran_ssn_last_four: '6789',
    veteran_file_number: '987654321',
    veteran_dob_day: '31',
    veteran_dob_month: '12',
    veteran_dob_year: '1969',
    veteran_service_number: '876543210',
    veteran_insurance_policy_number: '987654321123456789',
    signing_appellant_number_and_street: '456 First St Apt 5 Box 1',
    signing_appellant_city: 'Montreal',
    signing_appellant_country_code: 'CA',
    signing_appellant_zip_code: 'A9999AAA',
    signing_appellant_email: 'joe@email.com',
    claimant_type_code: 5,
    benefit_type_code: 1,
    form_5103_notice_acknowledged: 1,
    date_signed: '02/02/2023'
  }.each do |field, expected|
    it { expect(form_data.send(field)).to eq expected }
  end

  describe '#new_evidence_locations' do
    let(:form_data) { described_class.new(supplemental_claim) }

    it 'returns all the new evidence locations (with upload evidence indicated)' do
      evidence_locations = ['X-Ray VAMC', 'Blood Lab VA Facility',
                            "Doctor's Notes VAMC", 'CT scan VA Medical Facility',
                            'Lab work VAMC',
                            'Veteran indicated they will send evidence documents to VA.']
      expect(form_data.new_evidence_locations).to eq(evidence_locations)
    end

    it 'returns all the new evidence locations (without upload evidence indicated)' do
      # manually setting this to simulate a submission without upload indicated
      supplemental_claim.evidence_submission_indicated = false

      evidence_locations = ['X-Ray VAMC', 'Blood Lab VA Facility',
                            "Doctor's Notes VAMC", 'CT scan VA Medical Facility',
                            'Lab work VAMC']
      expect(form_data.new_evidence_locations).to eq(evidence_locations)
    end
  end

  describe '#new_evidence_dates' do
    it 'returns all the new evidence dates' do
      evidence_dates = [
        ['2020-04-10', '2020-01-02 to 2020-02-01', '2020-02-20 to 2020-02-22', '2019-02-02 to 2020-02-03'],
        ['2020-02-20 to 2020-02-22', '2020-02-02 to 2020-02-07'],
        %w[2020-04-10],
        ['2020-07-19', '2018-03-06 to 2019-02-12'],
        %w[2018-03-06 2018-01-15],
        ['']
      ]
      expect(form_data.new_evidence_dates).to eq(evidence_dates)
    end
  end

  describe '#form_5103_notice_acknowledged' do
    context "when benefit_type is not 'compensation'" do
      context "when 'form5103Acknowledged' value supplied" do
        let(:supplemental_claim) { build(:supplemental_claim) }

        it 'returns a nil value' do
          supplemental_claim.form_data['data']['attributes'].merge({ form5103Acknowledged: true })
          expect(form_data.form_5103_notice_acknowledged).to eq nil
        end
      end

      context "when benefit_type == 'compensation'" do
        context "when 'form5103Acknowledged' == true" do
          it { expect(form_data.form_5103_notice_acknowledged).to eq 1 }
        end

        context "when 'form5103Acknowledged' == false" do
          it do
            supplemental_claim.form_data['data']['attributes']['form5103Acknowledged'] = false
            expect(form_data.form_5103_notice_acknowledged).to eq 'Off'
          end
        end
      end
    end
  end

  describe 'phone number fields' do
    context 'domestic phone with no extension' do
      let(:supplemental_claim) { build(:supplemental_claim, created_at:) }

      it 'uses the domestic phone field' do
        expect(form_data.international_phone).to be_nil
        expect(form_data.phone_area_code).to eq '555'
        expect(form_data.phone_prefix).to eq '800'
        expect(form_data.phone_line_number).to eq '1111'
      end
    end

    context 'domestic phone with extension' do
      let(:supplemental_claim) { build(:extra_supplemental_claim, created_at:) }

      it 'uses the international phone field' do
        expect(form_data.international_phone).to eq '555-811-1100 ext 4'
        expect(form_data.phone_area_code).to be_nil
        expect(form_data.phone_prefix).to be_nil
        expect(form_data.phone_line_number).to be_nil
      end
    end

    context 'international phone' do
      let(:supplemental_claim) do
        build(:supplemental_claim, created_at:) do |sc|
          sc.form_data['data']['attributes']['veteran']['phone']['countryCode'] = '34'
          sc.form_data['data']['attributes']['veteran']['phone']['areaCode'] = '987'
          sc.form_data['data']['attributes']['veteran']['phone']['phoneNumber'] = '654321'
        end
      end

      it 'uses the international phone field' do
        expect(form_data.international_phone).to eq '+34-987654321'
        expect(form_data.phone_area_code).to be_nil
        expect(form_data.phone_prefix).to be_nil
        expect(form_data.phone_line_number).to be_nil
      end
    end
  end
end
