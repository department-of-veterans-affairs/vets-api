# frozen_string_literal: true

require 'rails_helper'

describe EMISRedis::MilitaryInformationV2, skip_emis: true do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :loa3) }

  describe '#last_entry_date' do
    it 'returns the begin date from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
        expect(subject.last_entry_date).to eq('2002-02-02')
      end
    end
  end

  describe '#service_branches' do
    it 'returns all the service branches someone has served under' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
        expect(subject.service_branches).to eq(['A'])
      end
    end
  end

  describe '#currently_active_duty_hash' do
    it 'returns false if service episode end date is in the past' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
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

  describe '#currently_active_duty' do
    it 'returns false if service episode end date is in the past' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
        expect(subject.currently_active_duty).to eq(false)
      end
    end
  end

  describe '#tours_of_duty' do
    it 'gets the tours of duty' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
        expect(subject.tours_of_duty).to eq(
          [{ service_branch: 'Army', date_range: { from: '2002-02-02', to: '2008-12-01' } }]
        )
      end
    end
  end

  describe '#service_periods' do
    it 'gets the service period' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
        expect(subject.service_periods).to eq(
          [{ service_branch: 'Army', date_range: { from: '2002-02-02', to: '2008-12-01' } }]
        )
      end
    end

    it 'gets the all service periods' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes') do
        expect(subject.service_periods).to eq(
          [{ service_branch: 'Army', date_range: { from: '2010-02-02', to: '2016-12-01' } },
           { service_branch: 'Army', date_range: { from: '2002-02-02', to: '2008-12-01' } }]
        )
      end
    end
  end

  describe '#last_discharge_date' do
    it 'returns the end date from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
        expect(subject.last_discharge_date).to eq('2008-12-01')
      end
    end
  end

  describe '#deployed_to?' do
    context 'with a deployment in the gulf war' do
      before do
        expect(subject).to receive(:deployments).and_return(
          [
            EMIS::Models::DeploymentV2.new(
              locations: [
                EMIS::Models::DeploymentLocationV2.new(
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
        VCR.use_cassette('emis/get_deployment_v2/valid') do
          expect(subject.deployed_to?(described_class::SOUTHWEST_ASIA, described_class::GULF_WAR_RANGE)).to eq(false)
        end
      end
    end
  end

  describe '#post_nov111998_combat' do
    context 'with post nov 1998 combat' do
      it 'returns true' do
        VCR.use_cassette('emis/get_deployment_v2/valid') do
          expect(subject.post_nov111998_combat).to eq(true)
        end
      end
    end

    context 'with no post nov 1998 combat' do
      before do
        expect(subject).to receive(:deployments).and_return(
          [
            EMIS::Models::DeploymentV2.new(end_date: Date.new(1998))
          ]
        )
      end

      it 'returns false' do
        expect(subject.post_nov111998_combat).to eq(false)
      end
    end
  end

  describe '#discharge_type' do
    it 'returns the discharge type from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
        expect(subject.discharge_type).to eq('general')
      end
    end
  end

  describe '#hca_last_service_branch' do
    context 'with service episodes' do
      it 'returns the last branch of service' do
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
          expect(subject.hca_last_service_branch).to eq('army')
        end
      end

      context 'with a code not in the list' do
        before do
          allow(subject).to receive(:service_episodes_by_date).and_return(
            [
              EMIS::Models::MilitaryServiceEpisodeV2.new(branch_of_service_code: 'foo')
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
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
          expect(subject.hca_last_service_branch).to be_nil
        end
      end
    end
  end

  describe '#last_service_branch' do
    context 'with service episodes' do
      it 'returns the last branch of service' do
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
          expect(subject.last_service_branch).to eq('Army')
        end
      end

      context 'with a code not in the list' do
        before do
          allow(subject).to receive(:service_episodes_by_date).and_return(
            [
              EMIS::Models::MilitaryServiceEpisodeV2.new(branch_of_service_code: 'foo')
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
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
          expect(subject.last_service_branch).to be_nil
        end
      end
    end
  end

  describe '#service_episodes_by_date' do
    let(:episode1) { EMIS::Models::MilitaryServiceEpisodeV2.new(end_date: Time.utc('2001')) }
    let(:episode2) { EMIS::Models::MilitaryServiceEpisodeV2.new(end_date: Time.utc('2000')) }
    let(:episode3) { EMIS::Models::MilitaryServiceEpisodeV2.new(end_date: Time.utc('1999')) }
    let(:episode_nil_end) { EMIS::Models::MilitaryServiceEpisodeV2.new(end_date: nil) }

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
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
          service_history = [
            service_history_object('Army', 'A', begin_date: '2002-02-02', end_date: '2008-12-01')
          ]

          expect(subject.service_history.as_json).to eq service_history
        end
      end
    end

    context 'with multiple military service episodes' do
      it 'for each episode, it should return the branch of service, start date, and end date' do
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes') do
          service_history = [
            service_history_object('Army', 'A', begin_date: '2010-02-02', end_date: '2016-12-01'),
            service_history_object('Army', 'A', begin_date: '2002-02-02', end_date: '2008-12-01')
          ]

          expect(subject.service_history.as_json).to eq service_history
        end
      end
    end

    context 'with a military service episode that has no end date' do
      it 'for each episode, it should return the branch of service, start date, and end date as nil' do
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid_no_end_date') do
          service_history = [
            service_history_object('Army', 'A', begin_date: '1990-11-02', end_date: nil),
            service_history_object('Army', 'A', begin_date: '1983-02-23', end_date: '1988-10-04')
          ]

          expect(subject.service_history.as_json).to eq service_history
        end
      end
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
