# frozen_string_literal: true
require 'rails_helper'

describe EMISRedis::MilitaryInformation, skip_emis: true do
  let(:user) { build :loa3_user }
  subject { described_class.for_user(user) }

  describe '#last_entry_date' do
    it 'should return the begin date from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.last_entry_date).to eq("2007-04-01")
      end
    end
  end

  describe '#last_discharge_date' do
    it 'should return the end date from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.last_discharge_date).to eq("2016-06-01")
      end
    end
  end

  describe '#sw_asia_combat' do
    context 'with a deployment in the gulf war' do
      before do
        expect(subject).to receive(:deployments).and_return([
          EMIS::Models::Deployment.new(
            locations: [
              EMIS::Models::DeploymentLocation.new(
                begin_date: Date.new(1991, 1, 1),
                end_date: Date.new(1991, 1, 2),
                iso_alpha3_country: 'IRQ'
              )
            ]
          )
        ])
      end

      it 'should return true' do
        expect(subject.sw_asia_combat).to eq(true)
      end
    end

    context 'without a deployment in the gulf war' do
      it 'should return false' do
        VCR.use_cassette('emis/get_deployment/valid') do
          expect(subject.sw_asia_combat).to eq(false)
        end
      end
    end
  end

  describe '#post_nov111998_combat' do
    context 'with post nov 1998 combat' do
      it 'should return true' do
        VCR.use_cassette('emis/get_deployment/valid') do
          expect(subject.post_nov111998_combat).to eq(true)
        end
      end
    end

    context 'with no post nov 1998 combat' do
      before do
        expect(subject).to receive(:deployments).and_return([
          EMIS::Models::Deployment.new(end_date: Date.new(1998))
        ])
      end

      it 'should return false' do
        expect(subject.post_nov111998_combat).to eq(false)
      end
    end
  end

  describe '#discharge_type' do
    it 'should return the discharge type from the latest service episode' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        expect(subject.discharge_type).to eq('dishonorable')
      end
    end
  end

  describe '#last_branch_of_service' do
    context 'with service episodes' do
      it 'should return the last branch of service' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          expect(subject.last_branch_of_service).to eq('air force')
        end
      end

      context 'with a code not in the list' do
        before do
          allow(subject).to receive(:service_episodes_by_date).and_return([
            EMIS::Models::MilitaryServiceEpisode.new(branch_of_service_code: 'foo')
          ])
        end

        it 'should return other' do
          expect(subject.last_branch_of_service).to eq('other')
        end
      end
    end

    context 'with no service episodes' do
      before do
        allow(subject).to receive(:service_episodes_by_date).and_return([])
      end
      it 'should return nil' do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          expect(subject.last_branch_of_service).to eq(nil)
        end
      end
    end
  end

  describe '#service_episodes_by_date' do
    let(:episode1) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('2001')) }
    let(:episode2) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('2000')) }
    let(:episode3) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('1999')) }

    it 'should return sorted service episodes latest first' do
      episodes = OpenStruct.new(
        items: [
          episode3,
          episode1,
          episode2
        ]
      )
      expect(subject).to receive(:emis_response).once.with('get_military_service_episodes').and_return(episodes)

      expect(subject.service_episodes_by_date).to eq([
        episode1,
        episode2,
        episode3
      ])
    end
  end
end
