# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/prefill/military_information'

# Spec tests for VAProfile::Prefill::MilitaryInformation class
describe VAProfile::Prefill::MilitaryInformation do
  # The main subject under test - an instance of VAProfile::Prefill::MilitaryInformation
  subject { described_class.new(user) }

  # Mock user object to simulate a logged-in user with LOA3 authentication
  let(:user) { build(:user, :loa3) }

  # # Tests related to the bio path of militaryPerson.militaryServiceHistory
  # context 'using bio path militaryPerson.militaryServiceHistory' do
  #   # Mock EDIPI (a unique identifier for personnel) for the user
  #   let(:edipi) { '1006753503' }

  #   before do
  #     # Stubbing user's EDIPI for controlled testing
  #     allow(user).to receive(:edipi).and_return(edipi)
  #   end

  #   # Test the method that fetches the last service branch the veteran was associated with
  #   describe '#last_service_branch' do
  #     it 'returns the most recent branch of military the veteran served under' do
  #       VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
  #         response = subject.last_service_branch
  #         expect(response).to eq('Army')
  #       end
  #     end
  #   end

  #   describe '#currently_active_duty' do
  #     it 'returns false if veteran is not currently serving in active duty' do
  #       VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
  #         response = subject.currently_active_duty

  #         expect(response).to eq(false)
  #       end
  #     end
  #   end

  #   describe '#currently_active_duty_hash' do
  #     it 'returns false if veteran is not currently serving in active duty' do
  #       VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
  #         response = subject.currently_active_duty_hash

  #         expect(response).to eq({ yes: false })
  #       end
  #     end
  #   end

  #   describe '#service_periods' do
  #     it 'returns an array of service periods with service branch and date range' do
  #       VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
  #         response = subject.service_periods

  #         expect(response).to be_an(Array)

  #         service_period = response.first
  #         expect(service_period).to have_key(:service_branch)
  #         expect(service_period).to have_key(:date_range)

  #         date_range = service_period[:date_range]
  #         expect(date_range).to have_key(:from)
  #         expect(date_range).to have_key(:to)
  #       end
  #     end
  #   end

  #   describe '#guard_reserve_service_history' do
  #     it 'returns an array of guard and reserve service episode date ranges sorted by end_date' do
  #       VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
  #         expected_response = [
  #           {:from=>"2000-04-07", :to=>"2009-01-23"},
  #           {:from=>"1989-08-20", :to=>"2002-07-01"},
  #           {:from=>"1989-08-20", :to=>"1992-08-23"}
  #         ]
  #         response = subject.guard_reserve_service_history

  #         expect(response).to be_an(Array)
  #         expect(response).to all(have_key(:from))
  #         expect(response).to all(have_key(:to))
  #         expect(response).to eq(expected_response)
  #       end
  #     end
  #   end

  #   describe '#latest_guard_reserve_service_period' do
  #     it 'returns the most recently completed guard or reserve service period' do
  #       VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
  #         response = subject.latest_guard_reserve_service_period

  #         expect(response).to eq({ from: '2000-04-07', to: '2009-01-23' })
  #       end
  #     end
  #   end
  # end

  # Tests related to the bio path of disabilityRating
  context 'using bio path disabilityRating. HIGH PERCENTAGE.' do
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

  context 'using bio path disabilityRating. LOW PERCENTAGE.' do
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
