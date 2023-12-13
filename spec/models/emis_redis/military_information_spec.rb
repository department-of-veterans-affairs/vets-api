# frozen_string_literal: true

require 'rails_helper'

describe EMISRedis::MilitaryInformation, skip_emis: true do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :loa3) }
  let(:ang_service_episode) do
    build(:service_episode, branch_of_service_code: 'F',
                            personnel_category_type_code: 'N')
  end
  let(:dod_service_epsiode) do
    build(:service_episode, branch_of_service_code: 'D',
                            personnel_category_type_code: 'A')
  end
  let(:army_reserve_service_epsiode) do
    build(:service_episode, branch_of_service_code: 'A',
                            personnel_category_type_code: 'V')
  end

  describe '#service_branch_used_in_disability' do
    it 'translates the service_episode codes to a string' do
      expect(subject.service_branch_used_in_disability(ang_service_episode)).to eq('Air National Guard')
      expect(subject.service_branch_used_in_disability(dod_service_epsiode)).to eq(nil)
      expect(subject.service_branch_used_in_disability(army_reserve_service_epsiode)).to eq('Army Reserve')
    end
  end

  describe '#currently_active_duty_hash' do
    it 'returns true if service episode end date is in the future' do
      allow(subject).to receive(:latest_service_episode).and_return(double(end_date: Date.current + 1.day))
      expect(subject.currently_active_duty_hash).to eq(
        yes: true
      )
    end

    it 'returns true if service episode end date is nil' do
      allow(subject).to receive(:latest_service_episode).and_return(double(end_date: nil))
      expect(subject.currently_active_duty_hash).to eq(
        yes: true
      )
    end

    it 'returns false if service episode is nil' do
      allow(subject).to receive(:latest_service_episode).and_return(nil)
      expect(subject.currently_active_duty_hash).to eq(
        yes: false
      )
    end
  end

  describe '#deployed_to?' do
    context 'with a deployment in the gulf war' do
      before do
        expect(subject).to receive(:deployments).and_return(
          [
            EMIS::Models::Deployment.new(
              locations: [
                EMIS::Models::DeploymentLocation.new(
                  begin_date: Date.new(1991, 1, 1),
                  end_date: Date.new(1991, 1, 2),
                  iso_alpha3_country: 'IRQ'
                )
              ]
            )
          ]
        )
      end

      it 'returns true' do
        expect(subject.deployed_to?(['IRQ'], described_class::GULF_WAR_RANGE)).to eq(true)
      end
    end
  end

  describe '#is_va_service_connected' do
    context 'with a disability with the right percent and amount' do
      before do
        expect(subject).to receive(:disabilities).and_return(
          [
            EMIS::Models::Disability.new(
              disability_percent: 50,
              pay_amount: 1
            )
          ]
        )
      end

      it 'returns true' do
        expect(subject.is_va_service_connected).to eq(true)
      end
    end

    context 'with a disability with one of the fields nil' do
      before do
        expect(subject).to receive(:disabilities).and_return(
          [
            EMIS::Models::Disability.new(
              disability_percent: nil,
              pay_amount: 1
            )
          ]
        )
      end

      it 'returns false' do
        expect(subject.is_va_service_connected).to eq(false)
      end
    end
  end

  describe '#va_compensation_type' do
    context 'with a disability of 50% or above' do
      before do
        expect(subject).to receive(:is_va_service_connected).and_return(true)
        expect(subject).to receive(:compensable_va_service_connected).and_return(false)
      end

      it 'returns "highDisability"' do
        expect(subject.va_compensation_type).to eq('highDisability')
      end
    end

    context 'with a disability less than 50%' do
      before do
        expect(subject).to receive(:is_va_service_connected).and_return(false)
        expect(subject).to receive(:compensable_va_service_connected).and_return(true)
      end

      it 'returns "lowDisability"' do
        expect(subject.va_compensation_type).to eq('lowDisability')
      end
    end
  end

  describe '#post_nov111998_combat' do
    context 'with no post nov 1998 combat' do
      before do
        expect(subject).to receive(:deployments).and_return(
          [
            EMIS::Models::Deployment.new(end_date: Date.new(1998))
          ]
        )
      end

      it 'returns false' do
        expect(subject.post_nov111998_combat).to eq(false)
      end
    end
  end

  describe '#discharge_type' do
    let(:military_information) { described_class.for_user(user) }

    it 'returns nil with an unknown discharge_character_of_service_code' do
      allow(military_information).to receive(:latest_service_episode).and_return(
        OpenStruct.new(
          discharge_character_of_service_code: nil
        )
      )

      expect(military_information.discharge_type).to eq(nil)
    end
  end

  describe '#hca_last_service_branch' do
    context 'with service episodes' do
      context 'with a code not in the list' do
        before do
          allow(subject).to receive(:service_episodes_by_date).and_return(
            [
              EMIS::Models::MilitaryServiceEpisode.new(branch_of_service_code: 'foo')
            ]
          )
        end

        it 'returns other' do
          expect(subject.hca_last_service_branch).to eq('other')
        end
      end
    end

    context 'with no service episodes' do
      before do
        allow(subject).to receive(:service_episodes_by_date).and_return([])
      end
    end
  end

  describe '#last_service_branch' do
    context 'with service episodes' do
      context 'with a code not in the list' do
        before do
          allow(subject).to receive(:service_episodes_by_date).and_return(
            [
              EMIS::Models::MilitaryServiceEpisode.new(branch_of_service_code: 'foo')
            ]
          )
        end

        it 'returns other' do
          expect(subject.last_service_branch).to be_nil
        end
      end
    end
  end

  describe '#service_episodes_by_date' do
    let(:episode1) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('2001')) }
    let(:episode2) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('2000')) }
    let(:episode3) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('1999')) }
    let(:episode_nil_end) { EMIS::Models::MilitaryServiceEpisode.new(end_date: nil) }

    it 'returns sorted service episodes latest first' do
      episodes = OpenStruct.new(
        items: [
          episode3,
          episode1,
          episode2
        ]
      )
      expect(subject).to receive(:emis_response).once.with('get_military_service_episodes').and_return(episodes)

      expect(subject.service_episodes_by_date).to eq(
        [
          episode1,
          episode2,
          episode3
        ]
      )
    end

    it 'treats a nil end date as the latest episode' do
      episodes = OpenStruct.new(
        items: [
          episode3,
          episode_nil_end,
          episode2
        ]
      )
      expect(subject).to receive(:emis_response).once.with('get_military_service_episodes').and_return(episodes)

      expect(subject.service_episodes_by_date).to eq(
        [
          episode_nil_end,
          episode2,
          episode3
        ]
      )
    end
  end

  describe '#guard_reserve_service_by_date' do
    let(:episode1) { EMIS::Models::GuardReserveServicePeriod.new(end_date: Time.utc('2001')) }
    let(:episode2) { EMIS::Models::GuardReserveServicePeriod.new(end_date: Time.utc('2000')) }
    let(:episode3) { EMIS::Models::GuardReserveServicePeriod.new(end_date: Time.utc('1999')) }
    let(:episode_nil_end) { EMIS::Models::GuardReserveServicePeriod.new(end_date: nil) }

    it 'returns sorted service episodes latest first' do
      episodes = OpenStruct.new(
        items: [
          episode3,
          episode1,
          episode2
        ]
      )
      expect(subject).to receive(:emis_response).once.with('get_guard_reserve_service_periods').and_return(episodes)

      expect(subject.guard_reserve_service_by_date).to eq(
        [
          episode1,
          episode2,
          episode3
        ]
      )
    end

    it 'treats a nil end date as the latest episode' do
      episodes = OpenStruct.new(
        items: [
          episode3,
          episode_nil_end,
          episode2
        ]
      )
      expect(subject).to receive(:emis_response).once.with('get_guard_reserve_service_periods').and_return(episodes)

      expect(subject.guard_reserve_service_by_date).to eq(
        [
          episode_nil_end,
          episode2,
          episode3
        ]
      )
    end
  end

  describe '#latest_guard_reserve_service_period' do
    let(:episode1) { EMIS::Models::GuardReserveServicePeriod.new(end_date: Time.utc('2001')) }
    let(:episode2) { EMIS::Models::GuardReserveServicePeriod.new(end_date: Time.utc('2000')) }

    it 'returns first period' do
      episodes = OpenStruct.new(
        items: [
          episode1,
          episode2
        ]
      )
      expect(subject).to receive(:emis_response).once.with('get_guard_reserve_service_periods').and_return(episodes)

      expect(subject.latest_guard_reserve_service_period).to eq(
        from: nil,
        to: episode1.end_date
      )
    end

    it 'returns nil if there are no service periods' do
      episodes = OpenStruct.new(
        items: nil
      )
      expect(subject).to receive(:emis_response).once.with('get_guard_reserve_service_periods').and_return(episodes)

      expect(subject.latest_guard_reserve_service_period).to eq(
        nil
      )
    end
  end
end

def service_history_object(branch_of_service = 'Air Force', personnel_category_type_code = 'V', begin_date:, end_date:)
  {
    'branch_of_service' => branch_of_service,
    'begin_date' => begin_date,
    'end_date' => end_date,
    'personnel_category_type_code' => personnel_category_type_code
  }
end

def reserve_guard_periods_object(from:, to:)
  {
    'from' => from,
    'to' => to
  }
end
