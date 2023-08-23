# frozen_string_literal: true

require 'rails_helper'
require 'hca/military_information'

describe HCA::MilitaryInformation do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  describe '#sw_asia_combat' do
    it 'returns if veteran was deployed to sw asia during gulf war' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        expect(subject.sw_asia_combat).to eq(false)
      end
    end
  end

  describe '#discharge_type' do
    it 'returns discharge type' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        expect(subject.discharge_type).to eq('general')
      end
    end

    it 'with an unknown character_of_discharge_code it returns nil' do
      # rubocop:disable RSpec/SubjectStub
      allow(subject).to receive(:latest_service_episode).and_return(
        OpenStruct.new(
          character_of_discharge_code: nil
        )
      )
      # rubocop:enable RSpec/SubjectStub

      expect(subject.discharge_type).to eq(nil)
    end
  end

  describe '#last_discharge_date' do
    it 'returns last end date' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        expect(subject.last_discharge_date).to eq('2018-10-31')
      end
    end
  end

  describe '#last_entry_date' do
    it 'returns last begin date' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        expect(subject.last_entry_date).to eq('2012-03-02')
      end
    end
  end

  describe '#post_nov111998_combat' do
    context 'with no post 1998 deployment' do
      it 'returns false' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
          expect(subject.post_nov111998_combat).to eq(false)
        end
      end
    end

    context 'with a post 1998 deployment' do
      it 'returns true' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          expect(subject.post_nov111998_combat).to eq(true)
        end
      end
    end
  end

  describe '#deployments' do
    it 'returns deployments' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        expect(
          subject.deployments.pluck('deployment_end_date')
        ).to eq(['2005-10-25'])
      end
    end
  end

  describe '#hca_last_service_branch' do
    context 'with a nil service branch code' do
      before do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:military_service_episodes).and_return(
          [
            OpenStruct.new(branch_of_service_code: nil)
          ]
        )
        # rubocop:enable RSpec/SubjectStub
      end

      it 'returns other' do
        expect(subject.hca_last_service_branch).to eq('other')
      end
    end

    it 'returns hca formatted last service branch' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        expect(subject.hca_last_service_branch).to eq('army')
      end
    end
  end

  describe '#service_episodes_by_date' do
    context 'with a nil end date' do
      before do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:military_service_episodes).and_return(
          [
            OpenStruct.new(end_date: '2018-10-31'),
            OpenStruct.new(end_date: nil)
          ]
        )
        # rubocop:enable RSpec/SubjectStub
      end

      it 'returns sorted military_service_episodes' do
        service_episodes_by_date = subject.service_episodes_by_date
        expect(service_episodes_by_date.map(&:end_date)).to eq([nil, '2018-10-31'])
      end
    end

    it 'returns sorted military_service_episodes' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        service_episodes_by_date = subject.service_episodes_by_date
        expect(service_episodes_by_date[0].end_date).to eq('2018-10-31')
        expect(service_episodes_by_date[2].end_date).to eq('2008-12-01')
      end
    end
  end

  describe '#military_service_episodes' do
    it 'returns military_service_episodes' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        military_service_episodes = subject.military_service_episodes
        expect(military_service_episodes.size).to eq(3)
        expect(military_service_episodes[0].branch_of_service).to eq('Army')
      end
    end
  end

  describe '#last_service_branch' do
    it 'returns the most recent branch of military the veteran served under' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        response = subject.last_service_branch
        expect(response).to eq('Army')
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

        expect(response).to eq({ yes: false })
      end
    end
  end

  describe '#service_periods' do
    it 'returns an array of service periods with service branch and date range' do
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
    it 'returns an array of guard and reserve service episode date ranges sorted by end_date' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        expected_response = [{ from: '2002-02-02', to: '2008-12-01' }]
        response = subject.guard_reserve_service_history

        expect(response).to be_an(Array)
        expect(response).to all(have_key(:from))
        expect(response).to all(have_key(:to))
        expect(response).to eq(expected_response)
      end
    end
  end

  describe '#latest_guard_reserve_service_period' do
    it 'returns the most recently completed guard or reserve service period' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        response = subject.latest_guard_reserve_service_period

        expect(response).to eq({ from: '2002-02-02', to: '2008-12-01' })
      end
    end
  end
end
