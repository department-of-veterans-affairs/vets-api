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

    describe '#service_periods' do
      it "returns an array of service periods with service branch and date range" do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.service_periods
    
          expect(response).to be_an(Array)
    
          service_period = response.first
          expect(service_period).to have_key(:service_branch)
          expect(service_period).to have_key(:date_range)
          
          date_range = service_period[:date_range]
          expect(date_range).to have_key(:from)
          expect(date_range).to have_key(:to)
        end
      end
    end

    describe '#guard_reserve_service_history' do
      it "returns an array of guard and reserve service episode date ranges sorted by end_date" do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          response = subject.guard_reserve_service_history
    
          expect(response).to be_an(Array)

          # Check structure of each episode in the response
          response.each do |episode|
            expect(episode).to have_key(:from)
            expect(episode).to have_key(:to)
          end
    
          # Ensure the array is sorted by :to in ascending order
          sorted_by_to_dates = response.map { |episode| episode[:to] }.compact.sort
          expect(response.map { |episode| episode[:to] }).to eq(sorted_by_to_dates)
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

    describe '#va_compensation_type' do
      it "returns 'highDisability' when veteran is paid for a highDisbility" do
        VCR.use_cassette('va_profile/disability/disability_rating_200') do
          response = subject.va_compensation_type
  
          expect(response).to eq('highDisability')
        end
      end
    end
  end
end