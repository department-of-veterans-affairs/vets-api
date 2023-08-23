# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/prefill/military_information'

describe VAProfile::Prefill::MilitaryInformation do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  context 'using bio path disabilityRating, HIGH PERCENTAGE' do
    let(:edipi) { '1005127153' }

    before do
      allow(user).to receive(:edipi).and_return(edipi)
    end

    describe '#is_va_service_connected' do
      it 'returns true if veteran is paid for a disability with a high disability percentage' do
        VCR.use_cassette('va_profile/disability/disability_rating_200_high_disability') do
          response = subject.is_va_service_connected

          expect(response).to eq(true)
        end
      end
    end

    describe '#compensable_va_service_connected' do
      it 'returns false if the rating percentage is not considered "low"' do
        VCR.use_cassette('va_profile/disability/disability_rating_200_high_disability') do
          response = subject.compensable_va_service_connected

          expect(response).to eq(false)
        end
      end
    end

    describe '#va_compensation_type' do
      it "returns 'highDisability' when veteran is paid for a highDisbility" do
        VCR.use_cassette('va_profile/disability/disability_rating_200_high_disability') do
          response = subject.va_compensation_type

          expect(response).to eq('highDisability')
        end
      end
    end
  end

  context 'using bio path disabilityRating, LOW PERCENTAGE' do
    let(:edipi) { '1148152574' }

    before do
      allow(user).to receive(:edipi).and_return(edipi)
    end

    describe '#is_va_service_connected' do
      it 'returns false if veteran is paid for a disability with a low disability percentage' do
        VCR.use_cassette('va_profile/disability/disabilityRating_200_low_disability') do
          response = subject.is_va_service_connected

          expect(response).to eq(false)
        end
      end
    end

    describe '#compensable_va_service_connected' do
      it 'returns true if veteran is paid for a disability with a low disability percentage' do
        VCR.use_cassette('va_profile/disability/disabilityRating_200_low_disability') do
          response = subject.compensable_va_service_connected

          expect(response).to eq(true)
        end
      end
    end

    describe '#va_compensation_type' do
      it "returns 'lowDisability' when veteran is paid for a lowDisbility" do
        VCR.use_cassette('va_profile/disability/disabilityRating_200_low_disability') do
          response = subject.va_compensation_type

          expect(response).to eq('lowDisability')
        end
      end
    end
  end
end
