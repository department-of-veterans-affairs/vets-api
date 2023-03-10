# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::HigherLevelReview::V3::FormData do
  let(:higher_level_review) { create(:extra_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }
  let(:form_data) { described_class.new(higher_level_review) }

  {
    veteran_ssn_first_three: '123',
    veteran_ssn_middle_two: '45',
    veteran_ssn_last_four: '6789',
    veteran_dob_day: '31',
    veteran_dob_month: '12',
    veteran_dob_year: '1969',
    veteran_email: 'bob@bobbytablesemail.com',
    claimant_ssn_first_three: '829',
    claimant_ssn_middle_two: '34',
    claimant_ssn_last_four: '7561',
    claimant_dob_month: '05',
    claimant_dob_day: '08',
    claimant_dob_year: '1972',
    informal_conference: 1,
    rep_first_name: 'Helen',
    rep_last_name: 'Holly',
    rep_email: 'holly@hellohellenholly.com',
    veteran_claimant_signature: "Betty D Boop\n- Signed by digital authentication to api.va.gov",
    veteran_claimant_date_signed_month: '02',
    veteran_claimant_date_signed_day: '03',
    veteran_claimant_date_signed_year: '2021'
  }.each do |key, value|
    it "#{key} = #{value}" do
      expect(form_data.send(key)).to eq value
    end
  end

  describe 'veteran phone handling' do
    context 'when domestic' do
      context 'without extension' do
        let(:higher_level_review) { build(:higher_level_review_v2) }

        it 'uses domestic fields' do
          {
            veteran_international_phone: nil,
            veteran_phone_area_code: '555',
            veteran_phone_prefix: '800',
            veteran_phone_line_number: '1111'
          }.each { |key, value| expect(form_data.send(key)).to eq value }
        end
      end

      context 'with extension' do
        let(:phone_data) { { 'areaCode' => '555', 'phoneNumber' => '8001111', 'phoneNumberExt' => '2' } }

        before do
          allow_any_instance_of(AppealsApi::Appellant).to receive(:domestic_phone?).and_return(true)
          allow_any_instance_of(AppealsApi::Appellant).to receive(:phone_data).and_return(phone_data)
        end

        it 'uses the international field' do
          {
            veteran_international_phone: '555-800-1111 ext 2',
            veteran_phone_area_code: nil,
            veteran_phone_prefix: nil,
            veteran_phone_line_number: nil
          }.each { |key, value| expect(form_data.send(key)).to eq value }
        end
      end
    end

    context 'when international' do
      it 'uses the international field' do
        {
          veteran_international_phone: '+34-555-800-1111 ex2',
          veteran_phone_area_code: nil,
          veteran_phone_prefix: nil,
          veteran_phone_line_number: nil
        }.each { |key, value| expect(form_data.send(key)).to eq value }
      end
    end
  end

  describe 'claimant phone handling' do
    context 'when domestic' do
      describe 'without extension' do
        let(:phone_data) { { 'areaCode' => '555', 'phoneNumber' => '8111100' } }

        before do
          allow_any_instance_of(AppealsApi::Appellant).to receive(:domestic_phone?).and_return(true)
          allow_any_instance_of(AppealsApi::Appellant).to receive(:phone_data).and_return(phone_data)
        end

        it 'uses domestic fields' do
          {
            claimant_international_phone: nil,
            claimant_phone_area_code: '555',
            claimant_phone_prefix: '811',
            claimant_phone_line_number: '1100'
          }.each { |key, value| expect(form_data.send(key)).to eq value }
        end
      end

      describe 'with extension' do
        it 'uses the international field' do
          {
            claimant_international_phone: '555-811-1100 ext 4',
            claimant_phone_area_code: nil,
            claimant_phone_prefix: nil,
            claimant_phone_line_number: nil
          }.each { |key, value| expect(form_data.send(key)).to eq value }
        end
      end
    end

    describe 'when international' do
      let(:phone_data) { { 'countryCode' => '34', 'areaCode' => '555', 'phoneNumber' => '8111100' } }

      before do
        allow_any_instance_of(AppealsApi::Appellant).to receive(:phone_data).and_return(phone_data)
      end

      it 'uses the international field' do
        {
          claimant_international_phone: '+34-555-811-1100',
          claimant_phone_area_code: nil,
          claimant_phone_prefix: nil,
          claimant_phone_line_number: nil
        }.each { |key, value| expect(form_data.send(key)).to eq value }
      end
    end
  end

  context 'rep phone handling' do
    describe 'when domestic' do
      it 'uses the domestic fields' do
        {
          rep_international_phone: nil,
          rep_phone_area_code: '555',
          rep_phone_prefix: '800',
          rep_phone_line_number: '1111',
          rep_phone_extension: 'x2'
        }.each { |key, value| expect(form_data.send(key)).to eq value }
      end
    end

    describe 'when international' do
      let(:higher_level_review) { build(:higher_level_review_v2) }

      it 'uses the international field' do
        {
          rep_international_phone: '+6-555-800-1111',
          rep_phone_area_code: nil,
          rep_phone_prefix: nil,
          rep_phone_line_number: nil,
          rep_phone_extension: nil
        }.each { |key, value| expect(form_data.send(key)).to eq value }
      end
    end
  end
end
