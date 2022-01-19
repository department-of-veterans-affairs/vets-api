# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NonVeteranClaimant, type: :model do
  include FixtureHelpers

  context 'when all headers and data are present' do
    let(:auth_headers) { fixture_as_json 'valid_200996_headers_extra_v2.json' }
    let(:default_form_data) { (fixture_as_json 'valid_200996_v2_extra.json') }
    let(:claimant_form_data) { default_form_data.dig('data', 'attributes', 'claimant') }
    let(:subject) { described_class.new(auth_headers: auth_headers, form_data: claimant_form_data) }

    describe '#first_name' do
      it { expect(subject.first_name).to eq 'Betty' }
    end

    describe '#middle_initial' do
      it { expect(subject.middle_initial).to eq 'D' }
    end

    describe '#last_name' do
      it { expect(subject.last_name).to eq 'Boop' }
    end

    describe '#ssn' do
      it { expect(subject.ssn).to eq '829347561' }
    end

    describe '#birth_date_string' do
      it { expect(subject.birth_date_string).to eq '1972-05-08' }
    end

    describe '#birth_month' do
      it { expect(subject.birth_month).to eq '05' }
    end

    describe '#birth_day' do
      it { expect(subject.birth_day).to eq '08' }
    end

    describe '#birth_year' do
      it { expect(subject.birth_year).to eq '1972' }
    end

    describe '#full_name' do
      it { expect(subject.full_name).to eq 'Betty D Boop' }
    end

    describe '#number_and_street' do
      it { expect(subject.number_and_street).to eq '456 First St Apt 5 Box 1' }
    end

    describe '#city' do
      it { expect(subject.city).to eq 'Detroit' }
    end

    describe '#state_code' do
      it { expect(subject.state_code).to eq 'MI' }
    end

    describe '#country_code' do
      it { expect(subject.country_code).to eq 'US' }
    end

    describe '#zip_code_5' do
      it { expect(subject.zip_code_5).to eq '48070' }
    end

    describe '#email' do
      it { expect(subject.email).to eq 'chocolate_chips@ilovecookies.com' }
    end

    describe '#phone_data' do
      it do
        expect(subject.phone_data).to include 'countryCode', 'areaCode', 'phoneNumber', 'phoneNumberExt'
      end
    end

    describe '#phone_string' do
      it do
        expect(subject.phone_string).to eq '555-811-1100 ext 4'
      end
    end
  end
end
