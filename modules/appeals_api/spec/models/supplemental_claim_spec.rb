# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::SupplementalClaim, type: :model do
  include FixtureHelpers

  context 'headers' do
    let(:auth_headers) { fixture_as_json 'valid_200995_headers.json' }
    let(:supplemental_claim) { create(:supplemental_claim) }

    describe 'veteran_first_name' do
      it { expect(supplemental_claim.veteran_first_name).to eq(auth_headers.dig('X-VA-First-Name')) }
    end

    describe 'veteran_middle_initial' do
      it { expect(supplemental_claim.veteran_middle_initial).to eq(auth_headers.dig('X-VA-Middle-Initial')) }
    end

    describe 'veteran_last_name' do
      it { expect(supplemental_claim.veteran_last_name).to eq(auth_headers.dig('X-VA-Last-Name')) }
    end

    describe 'full_name' do
      it { expect(supplemental_claim.full_name).to eq('Jäñe ø Doé') }
    end

    describe 'ssn' do
      it { expect(supplemental_claim.ssn).to eq(auth_headers.dig('X-VA-SSN')) }
    end

    describe 'file_number' do
      it { expect(supplemental_claim.file_number).to eq(auth_headers.dig('X-VA-File-Number')) }
    end

    describe 'veteran_dob_month' do
      it { expect(supplemental_claim.veteran_dob_month).to eq('12') }
    end

    describe 'veteran_dob_day' do
      it { expect(supplemental_claim.veteran_dob_day).to eq('31') }
    end

    describe 'veteran_dob_year' do
      it { expect(supplemental_claim.veteran_dob_year).to eq('1969') }
    end

    describe 'veteran_service_number' do
      it { expect(supplemental_claim.veteran_service_number).to eq(auth_headers.dig('X-VA-Service-Number')) }
    end

    describe 'consumer_name' do
      it { expect(supplemental_claim.consumer_name).to eq(auth_headers.dig('X-Consumer-Username')) }
    end

    describe 'consumer_id' do
      it { expect(supplemental_claim.consumer_id).to eq(auth_headers.dig('X-Consumer-ID')) }
    end
  end

  context 'extra form data' do
    let(:form_data) { fixture_as_json 'valid_200995_extra.json' }
    let(:supplemental_claim) { create(:extra_supplemental_claim) }
    let(:veteran) { form_data['data']['attributes']['veteran'] }

    context 'mailing address' do
      let(:address) { veteran['address'] }

      describe 'mailing_address_number_and_street' do
        it { expect(supplemental_claim.mailing_address_number_and_street).to eq(address['addressLine1']) }
      end

      describe 'mailing_address_apartment_or_unit_number' do
        it { expect(supplemental_claim.mailing_address_apartment_or_unit_number).to eq(address['addressLine2']) }
      end

      describe 'mailing_address_box' do
        it { expect(supplemental_claim.mailing_address_box).to eq(address['addressLine3']) }
      end

      describe 'mailing_address_city' do
        it { expect(supplemental_claim.mailing_address_city).to eq(address['city']) }
      end

      describe 'mailing_address_city_and_box' do
        it 'concatenates the city and p.o. box when provided' do
          city = address['city']
          box = address['addressLine3']

          expect(supplemental_claim.mailing_address_city_and_box).to eq("#{city} #{box}")
        end
      end

      describe 'mailing_address_state' do
        it { expect(supplemental_claim.mailing_address_state).to eq(address['stateCode']) }
      end

      describe 'mailing_address_country' do
        it { expect(supplemental_claim.mailing_address_country).to eq(address['countryCodeISO2']) }
      end

      describe 'zip_code_5' do
        it { expect(supplemental_claim.zip_code_5).to eq(address['zipCode5']) }
      end

      describe 'veteran_phone_data' do
        it { expect(supplemental_claim.veteran_phone_data).to eq(veteran['phone']) }
      end

      describe 'phone' do
        it { expect(supplemental_claim.phone).to eq '+03-555-800-1111' }
      end
    end
  end
end
