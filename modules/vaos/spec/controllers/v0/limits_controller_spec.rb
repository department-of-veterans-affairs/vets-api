# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS::V0::LimitsController', type: :request do
  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET /vaos/v0/facilities/{id}/limits' do
    context 'with a loa3 user' do
      let(:user) { FactoryBot.create(:user, :vaos) }

      it 'returns something' do
        #
        # get '/vaos/v0/facilities/limits?type_of_care_id=1toc&facility_id[]=1&facility_id[]=2'
        get '/vaos/v0/facilities/123/limits?type_of_care_id=1toc'
      end
    end
  end
end
