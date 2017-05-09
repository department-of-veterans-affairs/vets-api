# frozen_string_literal: true
require 'rails_helper'
require 'appeals_status/service'
require 'appeals_status/responses/get_appeals_response'

describe AppealsStatus::Service do
  let(:user) do
    user_hash = {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      middle_name: Faker::Name.last_name,
      birth_date: Faker::Date.between(50.years.ago, 20.years.ago).to_s,
      ssn: '796126859'
    }
    build(:loa3_user, user_hash)
  end
  let(:appeals_service) { AppealsStatus::Service.new }

  describe 'get_appeals' do
    context 'with a working mock for the user' do
      it 'returns the response' do
        expect(appeals_service.get_appeals(user)).to be_an_instance_of(AppealsStatus::Responses::GetAppealsResponse)
      end

      it 'has the appeals in the response' do
        expect(appeals_service.get_appeals(user).appeals.appeals.count).to eq(3)
      end

      it 'returns 200 as the status' do
        expect(appeals_service.get_appeals(user).status).to eq(200)
      end
    end
  end
end
