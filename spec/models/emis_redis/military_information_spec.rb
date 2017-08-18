# frozen_string_literal: true
require 'rails_helper'

describe EMISRedis::MilitaryInformation do
  let(:user) { build :loa3_user }
  subject { described_class.for_user(user) }

  describe '#last_branch_of_service' do
    it 'should return the last branch of service' do
      VCR.use_cassette('emis/get_military_service_episodes/valid') do
        subject.last_branch_of_service
      end
    end
  end

  describe '#service_episodes_by_date' do
    let(:episode1) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('2001')) }
    let(:episode2) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('2000')) }
    let(:episode3) { EMIS::Models::MilitaryServiceEpisode.new(end_date: Time.utc('1999')) }

    it 'should return sorted service episodes latest first' do
      episodes = [
        episode3,
        episode1,
        episode2
      ]
      expect(subject).to receive(:emis_response).once.with('get_military_service_episodes').and_return(episodes)

      expect(subject.service_episodes_by_date).to eq([
        episode1,
        episode2,
        episode3
      ])
    end
  end
end
