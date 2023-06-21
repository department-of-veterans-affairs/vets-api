# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::Appellant, type: :model do
  include FixtureHelpers

  let(:auth_headers) { fixture_as_json 'decision_reviews/v2/valid_200996_headers_extra.json' }
  let(:form_data) { fixture_as_json 'decision_reviews/v2/valid_200996_extra.json' }
  let(:veteran_form_data) { form_data.dig('data', 'attributes', 'veteran') }
  let(:claimant_form_data) { form_data.dig('data', 'attributes', 'claimant') }

  let(:veteran_appellant) do
    described_class.new(auth_headers:, form_data: veteran_form_data, type: :veteran)
  end

  let(:claimant_appellant) do
    described_class.new(auth_headers:, form_data: claimant_form_data, type: :claimant)
  end

  describe '#first_name' do
    it { expect(veteran_appellant.first_name).to eq 'Jäñe' }

    it { expect(claimant_appellant.first_name).to eq 'Betty' }
  end

  describe '#middle_initial' do
    it { expect(veteran_appellant.middle_initial).to eq 'ø' }
    it { expect(claimant_appellant.middle_initial).to eq 'D' }
  end

  describe '#last_name' do
    it { expect(veteran_appellant.last_name).to eq 'Doé' }
    it { expect(claimant_appellant.last_name).to eq 'Boop' }
  end

  describe '#ssn' do
    it { expect(veteran_appellant.ssn).to eq '123456789' }
    it { expect(claimant_appellant.ssn).to eq '829347561' }
  end

  describe '#birth_date_string' do
    it { expect(veteran_appellant.birth_date_string).to eq '1969-12-31' }
    it { expect(claimant_appellant.birth_date_string).to eq '1972-05-08' }
  end

  describe '#birth_month' do
    it { expect(veteran_appellant.birth_month).to eq '12' }
    it { expect(claimant_appellant.birth_month).to eq '05' }
  end

  describe '#birth_day' do
    it { expect(veteran_appellant.birth_day).to eq '31' }
    it { expect(claimant_appellant.birth_day).to eq '08' }
  end

  describe '#birth_year' do
    it { expect(veteran_appellant.birth_year).to eq '1969' }
    it { expect(claimant_appellant.birth_year).to eq '1972' }
  end

  describe '#full_name' do
    it { expect(veteran_appellant.full_name).to eq 'Jäñe ø Doé' }
    it { expect(claimant_appellant.full_name).to eq 'Betty D Boop' }
  end

  describe '#number_and_street' do
    it { expect(veteran_appellant.number_and_street).to eq '123 Main St Suite #1200 Box 4' }
    it { expect(claimant_appellant.number_and_street).to eq '456 First St Apt 5 Box 1' }
  end

  describe '#city' do
    it { expect(veteran_appellant.city).to eq 'New York' }
    it { expect(claimant_appellant.city).to eq 'Detroit' }
  end

  describe '#state_code' do
    it { expect(veteran_appellant.state_code).to eq 'NY' }
    it { expect(claimant_appellant.state_code).to eq 'MI' }
  end

  describe '#country_code' do
    it { expect(veteran_appellant.country_code).to eq 'US' }
    it { expect(claimant_appellant.country_code).to eq 'US' }
  end

  describe '#zip_code_5' do
    it { expect(veteran_appellant.zip_code_5).to eq '30012' }
    it { expect(claimant_appellant.zip_code_5).to eq '48070' }
  end

  describe '#international_postal_code' do
    let(:auth_headers) { fixture_as_json 'decision_reviews/v2/valid_200995_headers_extra.json' }
    let(:form_data) { fixture_as_json 'decision_reviews/v2/valid_200995_extra.json' }
    let(:claimant_form_data) { form_data.dig('data', 'attributes', 'claimant') }

    let(:claimant_appellant) do
      described_class.new(auth_headers:, form_data: claimant_form_data, type: :claimant)
    end

    it { expect(claimant_appellant.zip_code_5).to eq '00000' }
    it { expect(claimant_appellant.international_postal_code).to eq 'A9999AAA' }
  end

  describe '#homeless?' do
    it { expect(veteran_appellant.homeless?).to eq true }
    #  TODO: determine how to handle for non-veteran claimant in future
  end

  context 'when no address for claimant' do
    let(:no_address_data) { claimant_form_data.delete('address') }
    let(:claimant_appellant) do
      described_class.new(auth_headers:, form_data: no_address_data, type: :claimant)
    end

    describe '#number_and_street' do
      it { expect(claimant_appellant.number_and_street).to eq nil }
    end

    describe '#city' do
      it { expect(claimant_appellant.city).to eq nil }
    end

    describe '#state_code' do
      it { expect(claimant_appellant.state_code).to eq nil }
    end

    describe '#country_code' do
      it { expect(claimant_appellant.country_code).to eq nil }
    end

    describe '#zip_code_5' do
      it { expect(claimant_appellant.zip_code_5).to eq nil }
    end
  end

  describe '#email' do
    it do
      expect(veteran_appellant.email).to eq 'bob@bobbytablesemail.com'
    end

    it do
      expect(claimant_appellant.email).to eq 'claimant@email.com'
    end
  end

  describe '#phone_data' do
    it { expect(veteran_appellant.phone_data).to include 'countryCode', 'areaCode', 'phoneNumber', 'phoneNumberExt' }
    it { expect(claimant_appellant.phone_data).to include 'countryCode', 'areaCode', 'phoneNumber', 'phoneNumberExt' }
  end

  describe '#phone_country_code' do
    it { expect(veteran_appellant.phone_country_code).to eq '34' }
    it { expect(claimant_appellant.phone_country_code).to eq '1' }
  end

  describe '#timezone' do
    it { expect(veteran_appellant.timezone).to eq 'America/Chicago' }
    it { expect(claimant_appellant.timezone).to eq 'America/Detroit' }
  end

  describe '#signing_appellant?' do
    it { expect(veteran_appellant.signing_appellant?).to eq false }
    it { expect(claimant_appellant.signing_appellant?).to eq true }
  end
end
