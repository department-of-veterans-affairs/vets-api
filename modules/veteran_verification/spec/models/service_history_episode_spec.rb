# frozen_string_literal: true

require 'rails_helper'

describe VeteranVerification::ServiceHistoryEpisode, skip_emis: true do
  let(:user) { build(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3)) }

  describe '#formatted_episodes' do
    it 'returns service history and deployments' do
      VCR.use_cassette('emis/get_deployment_v2/valid') do
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
          result = described_class.for_user(user)
          expect(result.length).to eq(1)
          expect(result[0][:first_name]).to eq('abraham')
          expect(result[0][:last_name]).to eq('lincoln')
          expect(result[0][:branch_of_service]).to eq('Army National Guard')
          expect(result[0][:pay_grade]).to eq('W04')
          expect(result[0][:deployments][0][:location]).to eq('AX1')
        end
      end
    end

    it 'returns service history and deploys when there are multiple episodes' do
      VCR.use_cassette('emis/get_deployment_v2/valid') do
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes') do
          result = described_class.for_user(user)
          expect(result.length).to eq(2)
          expect(result[0][:first_name]).to eq('abraham')
          expect(result[0][:last_name]).to eq('lincoln')
          expect(result[0][:branch_of_service]).to eq('Army National Guard')
          expect(result[0][:pay_grade]).to eq('W04')
          expect(result[0][:deployments][0][:location]).to eq('AX1')
        end
      end
    end

    it 'returns service history and deploys when there are multiple episodes and end date null' do
      VCR.use_cassette('emis/get_deployment_v2/valid') do
        VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes_end_date_null') do
          result = described_class.for_user(user)
          expect(result.length).to eq(2)
          expect(result[0][:branch_of_service]).to eq('Army National Guard')
          expect(result[0][:pay_grade]).to eq('W04')
          expect(result[0][:deployments].length).to eq(0)
          expect(result[1][:branch_of_service]).to eq('Army National Guard')
          expect(result[1][:pay_grade]).to eq('W04')
          expect(result[1][:deployments].length).to eq(3)
        end
      end
    end

    it 'returns service history and deployments but missing pay_grade' do
      VCR.use_cassette('emis/get_deployment_v2/valid') do
        VCR.use_cassette('emis/get_military_service_episodes_v2/invalid_missing_pay_plan') do
          result = described_class.for_user(user)
          expect(result.length).to eq(1)
          expect(result[0][:branch_of_service]).to eq('Army National Guard')
          expect(result[0][:pay_grade]).to eq('unknown')
          expect(result[0][:deployments][0][:location]).to eq('AX1')
        end
      end
    end
  end
end
