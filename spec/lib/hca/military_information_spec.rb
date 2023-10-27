# frozen_string_literal: true

require 'rails_helper'
require 'hca/military_information'

describe HCA::MilitaryInformation do
  let(:military_information) { described_class.new(user) }

  let(:user) { build(:user, :loa3) }
  let(:edipi) { '384759483' }

  before do
    allow(user).to receive(:edipi).and_return(edipi)
  end

  describe '#sw_asia_combat' do
    it 'returns if veteran was deployed to sw asia during gulf war' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        expect(military_information.sw_asia_combat).to eq(false)
      end
    end
  end

  describe '#discharge_type' do
    it 'returns discharge type' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        expect(military_information.discharge_type).to eq('general')
      end
    end

    it 'with an unknown character_of_discharge_code it returns nil' do
      allow(military_information).to receive(:latest_service_episode).and_return(
        OpenStruct.new(
          character_of_discharge_code: nil
        )
      )

      expect(military_information.discharge_type).to eq(nil)
    end
  end

  describe '#last_discharge_date' do
    it 'returns last end date' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        expect(military_information.last_discharge_date).to eq('2018-10-31')
      end
    end
  end

  describe '#last_entry_date' do
    it 'returns last begin date' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        expect(military_information.last_entry_date).to eq('2012-03-02')
      end
    end
  end

  describe '#post_nov111998_combat' do
    context 'with no post 1998 deployment' do
      it 'returns false' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
          expect(military_information.post_nov111998_combat).to eq(false)
        end
      end
    end

    context 'with a post 1998 deployment' do
      it 'returns true' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
          expect(military_information.post_nov111998_combat).to eq(true)
        end
      end
    end
  end

  describe '#deployments' do
    it 'returns deployments' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
        expect(
          military_information.deployments.pluck('deployment_end_date')
        ).to eq(['2005-10-25'])
      end
    end
  end

  describe '#hca_last_service_branch' do
    context 'with a nil service branch code' do
      before do
        expect(military_information).to receive(:military_service_episodes).and_return(
          [
            OpenStruct.new(branch_of_service_code: nil)
          ]
        )
      end

      it 'returns other' do
        expect(military_information.hca_last_service_branch).to eq('other')
      end
    end

    it 'returns hca formatted last service branch' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        expect(military_information.hca_last_service_branch).to eq('army')
      end
    end
  end

  describe '#service_episodes_by_date' do
    context 'with a nil end date' do
      before do
        expect(military_information).to receive(:military_service_episodes).and_return(
          [
            OpenStruct.new(end_date: '2018-10-31'),
            OpenStruct.new(end_date: nil)
          ]
        )
      end

      it 'returns sorted military_service_episodes' do
        service_episodes_by_date = military_information.service_episodes_by_date
        expect(service_episodes_by_date.map(&:end_date)).to eq([nil, '2018-10-31'])
      end
    end

    it 'returns sorted military_service_episodes' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        service_episodes_by_date = military_information.service_episodes_by_date
        expect(service_episodes_by_date[0].end_date).to eq('2018-10-31')
        expect(service_episodes_by_date[2].end_date).to eq('2008-12-01')
      end
    end
  end

  describe '#military_service_episodes' do
    it 'returns military_service_episodes' do
      VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
        military_service_episodes = military_information.military_service_episodes
        expect(military_service_episodes.size).to eq(3)
        expect(military_service_episodes[0].branch_of_service).to eq('Army')
      end
    end
  end
end
