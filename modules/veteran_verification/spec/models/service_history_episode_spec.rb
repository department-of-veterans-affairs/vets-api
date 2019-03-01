# frozen_string_literal: true

require 'rails_helper'

describe VeteranVerification::ServiceHistoryEpisode, skip_emis: true do
  let(:user) { build(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3)) }

  describe '#formatted_episodes' do
    it 'should return service history and deployments' do
      VCR.use_cassette('emis/get_deployment/valid') do
        VCR.use_cassette('emis/get_military_service_episodes/valid') do
          result = described_class.for_user(user)
          expect(result.length).to eq(1)
          expect(result[0][:branch_of_service]).to eq('Air Force Reserve')
          expect(result[0][:deployments][0][:location]).to eq('ARE')
        end
      end
    end

    it 'should return service history and deploys when there are multiple episodes' do
      VCR.use_cassette('emis/get_deployment/valid') do
        VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
          result = described_class.for_user(user)
          expect(result.length).to eq(2)
          expect(result[0][:branch_of_service]).to eq('Air Force Reserve')
          expect(result[0][:deployments][0][:location]).to eq('ARE')
        end
      end
    end
  end
end
