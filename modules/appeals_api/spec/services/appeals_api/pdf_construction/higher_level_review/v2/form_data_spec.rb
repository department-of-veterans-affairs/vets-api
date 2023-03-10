# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::HigherLevelReview::V2::FormData do
  let(:higher_level_review) { create(:extra_higher_level_review_v2) }
  let(:signing_appellant) { higher_level_review.signing_appellant }
  let(:form_data) { described_class.new(higher_level_review) }

  describe '#veteran_phone_string' do
    it { expect(form_data.veteran_phone_string).to eq '+34-555-800-1111 ex2' }
  end

  describe '#veteran_area_code' do
    # does not print on form when international number present
    it { expect(form_data.veteran_area_code).to eq nil }
  end

  describe '#veteran_phone_prefix' do
    # does not print on form when international number present
    it { expect(form_data.veteran_phone_prefix).to eq nil }
  end

  describe '#veteran_phone_line_number' do
    # does not print on form when international number present
    it { expect(form_data.veteran_phone_line_number).to eq nil }
  end

  describe '#veteran_international_number' do
    it { expect(form_data.veteran_international_number).to eq '+34-555-800-1111 ex2' }
  end

  describe '#veteran_email' do
    it do
      expect(form_data.veteran_email).to eq 'bob@bobbytablesemail.com'
    end
  end

  describe '#veteran_ssn_first_three' do
    it { expect(form_data.veteran_ssn_first_three).to eq '123' }
  end

  describe '#veteran_ssn_second_two' do
    it { expect(form_data.veteran_ssn_second_two).to eq '45' }
  end

  describe '#veteran_ssn_last_four' do
    it { expect(form_data.veteran_ssn_last_four).to eq '6789' }
  end

  describe '#claimant_phone_string' do
    it { expect(form_data.claimant_phone_string).to eq '555-811-1100 ext 4' }
  end

  describe '#claimant_area_code' do
    it { expect(form_data.claimant_area_code).to eq '555' }
  end

  describe '#claimant_phone_prefix' do
    it { expect(form_data.claimant_phone_prefix).to eq '811' }
  end

  describe '#claimant_phone_line_number' do
    it { expect(form_data.claimant_phone_line_number).to eq '1100' }
  end

  describe '#claimant_international_number' do
    it { expect(form_data.claimant_international_number).to eq nil }
  end

  describe '#claimant_phone_ext' do
    it { expect(form_data.claimant_phone_ext).to eq '4' }
  end

  describe '#claimant_ssn_first_three' do
    it { expect(form_data.claimant_ssn_first_three).to eq '829' }
  end

  describe '#claimant_ssn_second_two' do
    it { expect(form_data.claimant_ssn_second_two).to eq '34' }
  end

  describe '#claimant_ssn_last_four' do
    it { expect(form_data.claimant_ssn_last_four).to eq '7561' }
  end

  describe '#rep_country_code' do
    it 'defaults to 1 if countryCode is blank' do
      higher_level_review = build_stubbed(:higher_level_review_v2)
      form_data = described_class.new(higher_level_review)
      allow(higher_level_review).to receive(:informal_conference_rep_phone).and_return(
        AppealsApi::HigherLevelReview::Phone.new(
          { 'areaCode' => '555', 'phoneNumber' => '8001111', 'phoneNumberExt' => '2' }
        )
      )

      expect(form_data.rep_country_code).to eq('1')
    end
  end

  describe '#signature' do
    context 'when veteran appellant' do
      let(:hlr_veteran_only) { create(:minimal_higher_level_review_v2) }
      let(:form_data) { described_class.new(hlr_veteran_only) }

      it { expect(form_data.signature).to eq "Jane Doe\n- Signed by digital authentication to api.va.gov" }
    end

    context 'when claimant appellant' do
      it { expect(form_data.signature).to eq "Betty D Boop\n- Signed by digital authentication to api.va.gov" }
    end
  end

  describe '#date_signed formatted' do
    let(:month) { Time.now.in_time_zone(signing_appellant.timezone).strftime('%m') }
    let(:day) { Time.now.in_time_zone(signing_appellant.timezone).strftime('%d') }
    let(:year) { Time.now.in_time_zone(signing_appellant.timezone).strftime('%Y') }

    it { expect(form_data.date_signed_mm).to eq month }
    it { expect(form_data.date_signed_dd).to eq day }
    it { expect(form_data.date_signed_yyyy).to eq year }
  end

  context 'when delegating to hlr' do
    describe '#contestable_issues' do
      it do
        expect(higher_level_review).to receive(:contestable_issues)
        form_data.contestable_issues
      end
    end

    describe '#signing_appellant' do
      it do
        expect(higher_level_review).to receive(:signing_appellant)
        form_data.signing_appellant
      end
    end

    describe '#appellant_local_time' do
      it do
        expect(higher_level_review).to receive(:appellant_local_time)
        form_data.appellant_local_time
      end
    end

    describe '#veteran_homeless?' do
      it do
        expect(higher_level_review).to receive(:veteran_homeless?)
        form_data.veteran_homeless?
      end
    end

    describe '#veteran' do
      it do
        expect(higher_level_review).to receive(:veteran)
        form_data.veteran
      end
    end

    describe '#claimant' do
      it do
        expect(higher_level_review).to receive(:claimant)
        form_data.claimant
      end
    end
  end
end
