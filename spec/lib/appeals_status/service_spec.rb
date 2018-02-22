# frozen_string_literal: true

require 'rails_helper'
require 'appeals_status/service'
require 'appeals_status/responses/get_appeals_response'

describe AppealsStatus::Service do
  let(:appeals_service) { AppealsStatus::Service.new }

  describe 'get_appeals' do
    context 'with a working mock for the user and no hearings' do
      let(:user) do
        user_hash = {
          first_name: Faker::Name.first_name,
          last_name: Faker::Name.last_name,
          middle_name: Faker::Name.last_name,
          birth_date: Faker::Date.between(50.years.ago, 20.years.ago).to_s,
          ssn: '111224444'
        }
        build(:user, :loa3, user_hash)
      end

      it 'returns the response' do
        expect(appeals_service.get_appeals(user)).to be_an_instance_of(AppealsStatus::Responses::GetAppealsResponse)
      end

      it 'has the appeals in the response' do
        expect(appeals_service.get_appeals(user).appeals.data.count).to eq(1)
      end

      it 'returns 200 as the status' do
        expect(appeals_service.get_appeals(user).status).to eq(200)
      end

      it 'contains the events' do
        expect(appeals_service.get_appeals(user).appeals.data.first.events.count).to eq(6)
      end
    end

    context 'with a working mock for the user and some hearings' do
      let(:user) do
        user_hash = {
          first_name: Faker::Name.first_name,
          last_name: Faker::Name.last_name,
          middle_name: Faker::Name.last_name,
          birth_date: Faker::Date.between(50.years.ago, 20.years.ago).to_s,
          ssn: '111223333'
        }
        build(:user, :loa3, user_hash)
      end

      it 'returns the response' do
        expect(appeals_service.get_appeals(user)).to be_an_instance_of(AppealsStatus::Responses::GetAppealsResponse)
      end

      it 'has the appeals in the response' do
        expect(appeals_service.get_appeals(user).appeals.data.count).to eq(1)
      end

      it 'returns 200 as the status' do
        expect(appeals_service.get_appeals(user).status).to eq(200)
      end

      it 'contains the hearings' do
        expect(appeals_service.get_appeals(user).appeals.data.first.hearings.count).to eq(1)
      end
    end

    context 'with real responses' do
      let(:user) do
        user_hash = {
          first_name: Faker::Name.first_name,
          last_name: Faker::Name.last_name,
          middle_name: Faker::Name.last_name,
          birth_date: Faker::Date.between(50.years.ago, 20.years.ago).to_s,
          ssn: '111223333'
        }
        build(:user, :loa3, user_hash)
      end

      before do
        allow(appeals_service).to receive(:should_mock?) { false }
      end

      it 'returns the real response' do
        VCR.use_cassette('appeals_status/valid_appeals') do
          expect(appeals_service.get_appeals(user)).to be_an_instance_of(AppealsStatus::Responses::GetAppealsResponse)
        end
      end

      it 'contains the appeals' do
        VCR.use_cassette('appeals_status/valid_appeals') do
          expect(appeals_service.get_appeals(user).appeals.data.count).to eq(1)
        end
      end
    end
  end
end
