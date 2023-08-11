# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/prefill/military_information'

describe VAProfile::Prefill::MilitaryInformation do
  subject { described_class.new(user) }
  let(:user) { build(:user, :loa3) }

  context 'using bio path militaryPerson.militaryServiceHistory' do
    let(:edipi) { '384759483' }

    before do
      allow(user).to receive(:edipi).and_return(edipi)
    end
  
    describe '#last_service_branch' do
      it 'returns the most recent branch of military the veteran served under' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.last_service_branch
  
          expect(response).to eq("Army")
        end
      end
    end
  
    describe '#currently_active_duty' do
      it 'returns false if veteran is not currently serving in active duty' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.currently_active_duty
  
          expect(response).to eq(false)
        end
      end
    end
  
    describe '#currently_active_duty_hash' do
      it 'returns false if veteran is not currently serving in active duty' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.currently_active_duty_hash
  
          expect(response).to eq({ yes: false})
        end
      end
    end
  
    describe '#currently_active_duty_hash' do
      it 'returns false if veteran is not currently serving in active duty' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.currently_active_duty_hash
  
          expect(response).to eq({ yes: false})
        end
      end
    end  
  end

  context 'using bio path disabilityRating' do
    let(:edipi) { '1005127153' }

    before do
      allow(user).to receive(:edipi).and_return(edipi)
    end

    describe '#is_va_service_connected' do
      it 'returns false if veteran is not currently serving in active duty' do
        VCR.use_cassette('va_profile/disability/disability_rating_200') do
          response = subject.is_va_service_connected
  
          expect(response).to eq(true)
        end
      end
    end

    describe '#is_va_service_connected' do
      it 'returns true if true if veteran is paid for a disability with a high disability percentage' do
        VCR.use_cassette('va_profile/disability/disability_rating_200') do
          response = subject.is_va_service_connected
  
          expect(response).to eq(true)
        end
      end
    end

    describe '#compensable_va_service_connected' do
      it 'returns false if true if veteran is not paid for a disability with a low disability percentage' do
        VCR.use_cassette('va_profile/disability/disability_rating_200') do
          response = subject.compensable_va_service_connected
  
          expect(response).to eq(false)
        end
      end
    end 
  end
end