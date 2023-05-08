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

  describe '#last_entry_date' do
    it 'returns the begin date from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.last_entry_date).to eq('2007-04-01')
      end
    end
  end

  describe '#service_branch_used_in_disability' do
    it 'translates the service_episode codes to a string' do
      expect(subject.service_branch_used_in_disability(ang_service_episode)).to eq('Air National Guard')
      expect(subject.service_branch_used_in_disability(dod_service_epsiode)).to eq(nil)
      expect(subject.service_branch_used_in_disability(army_reserve_service_epsiode)).to eq('Army Reserve')
    end
  end

  describe '#service_branches' do
    it 'returns all the service branches someone has served under' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.service_branches).to eq(['F'])
      end
    end
  end

  describe '#currently_active_duty_hash' do
    it 'returns false if service episode end date is in the past' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.currently_active_duty_hash).to eq(
          yes: false
        )
      end
    end

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

  describe '#tours_of_duty' do
    it 'gets the tours of duty' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.tours_of_duty).to eq(
          [{ service_branch: 'Air Force', date_range: { from: '2007-04-01', to: '2016-06-01' } }]
        )
      end
    end
  end

  describe '#service_periods' do
    it 'gets the service period' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.service_periods).to eq(
          [{ service_branch: 'Air Force Reserve', date_range: { from: '2007-04-01', to: '2016-06-01' } }]
        )
      end
    end

    it 'gets the all service periods' do
      VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
        expect(subject.service_periods).to eq(
          [{ service_branch: 'Air Force Reserve', date_range: { from: '2007-04-01', to: '2016-06-01' } },
           { service_branch: 'Air Force Reserve', date_range: { from: '2000-02-01', to: '2004-06-14' } }]
        )
      end
    end
  end

  describe '#last_discharge_date' do
    it 'returns the end date from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.last_discharge_date).to eq('2016-06-01')
      end
    end
  end

  describe '#compensable_va_service_connected' do
    context 'with a disability with the right percent' do
      it 'returns true' do
        VCR.use_cassette('emis/get_disabilities/valid') do
          expect(subject.compensable_va_service_connected).to eq(true)
        end
      end
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

    context 'without a deployment in the gulf war' do
      it 'returns false' do
        VCR.use_cassette('emis/get_deployment/valid') do
          expect(subject.deployed_to?(described_class::SOUTHWEST_ASIA, described_class::GULF_WAR_RANGE)).to eq(false)
        end
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
    context 'with post nov 1998 combat' do
      it 'returns true' do
        VCR.use_cassette('emis/get_deployment/valid') do
          expect(subject.post_nov111998_combat).to eq(true)
        end
      end
    end

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

    it 'returns the discharge type from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.discharge_type).to eq('dishonorable')
      end
    end
  end

  describe '#hca_last_service_branch' do
    context 'with service episodes' do
      it 'returns the last branch of service' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          expect(subject.hca_last_service_branch).to eq('air force')
        end
      end

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

      it 'returns nil' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          expect(subject.hca_last_service_branch).to be_nil
        end
      end
    end
  end

  describe '#last_service_branch' do
    context 'with service episodes' do
      it 'returns the last branch of service' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          expect(subject.last_service_branch).to eq('Air Force')
        end
      end

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

    context 'with no service episodes' do
      before do
        allow(subject).to receive(:service_episodes_by_date).and_return([])
      end

      it 'returns nil' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
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

  describe '#service_history' do
    context 'with one military service episode' do
      it 'for the episode, it should return the branch of service, start date, and end date' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          service_history = [
            service_history_object('Air Force', 'V', begin_date: '2007-04-01', end_date: '2016-06-01')
          ]

          expect(subject.service_history.as_json).to eq service_history
        end
      end
    end

    context 'with multiple military service episodes' do
      it 'for each episode, it should return the branch of service, start date, and end date' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
          service_history = [
            service_history_object(begin_date: '2007-04-01', end_date: '2016-06-01'),
            service_history_object(begin_date: '2000-02-01', end_date: '2004-06-14')
          ]

          expect(subject.service_history.as_json).to eq service_history
        end
      end
    end

    context 'with a military service episode that has no end date' do
      it 'for each episode, it should return the branch of service, start date, and end date as nil' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_no_end_date') do
          service_history = [
            service_history_object('Army', 'A', begin_date: '1990-11-02', end_date: nil),
            service_history_object('Army', 'A', begin_date: '1983-02-23', end_date: '1988-10-04')
          ]

          expect(subject.service_history.as_json).to eq service_history
        end
      end
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

  describe '#guard_reserve_service_history' do
    context 'with one reserve/guard service period' do
      it 'for the period, it should return the "from" date and the "to" date' do
        VCR.use_cassette('emis/get_guard_reserve_service_periods/valid') do
          service_periods = [
            reserve_guard_periods_object(from: '2007-05-22', to: '2008-06-05')
          ]

          expect(subject.guard_reserve_service_history.as_json).to eq service_periods
        end
      end
    end

    context 'with a reserve/guard service period that has no end date' do
      it 'for the period, it should return the "from" date and the "to" date' do
        VCR.use_cassette('emis/get_guard_reserve_service_periods/valid_no_end_date') do
          service_periods = [
            reserve_guard_periods_object(from: '2007-05-22', to: nil)
          ]
          expect(subject.guard_reserve_service_history.as_json).to eq service_periods
        end
      end
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
