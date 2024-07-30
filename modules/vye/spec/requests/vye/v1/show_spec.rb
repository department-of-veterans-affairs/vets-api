# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::V1::UserInfosController, type: :request do
  describe 'GET /vye/v1' do
    describe 'when there is a logged in current_user' do
      let!(:current_user) { create(:user, :accountable) }

      before do
        allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
      end

      describe 'GET /vye/v1 with flag turned off' do
        before do
          Flipper.disable :vye_request_allowed
        end

        it 'does not accept the request' do
          get '/vye/v1'
          expect(response).to have_http_status(:bad_request)
        end
      end

      describe 'GET /vye/v1 with flag turned on' do
        before do
          Flipper.enable :vye_request_allowed
        end

        describe 'where current_user is not in VYE' do
          it 'does not accept the request' do
            get '/vye/v1'
            expect(response).to have_http_status(:forbidden)
          end
        end

        describe 'where current_user is in VYE' do
          let!(:user_profile) { FactoryBot.create(:vye_user_profile, icn: current_user.icn) }
          let!(:user_info) { FactoryBot.create(:vye_user_info, user_profile:) }

          it 'returns the user_info' do
            get '/vye/v1'
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end
end

# "vye/user_info"=>
#   {"rem_ent"=>"2421128",
#    "cert_issue_date"=>"2021-04-18",
#    "del_date"=>"2025-04-14",
#    "date_last_certified"=>"2024-06-04",
#    "payment_amt"=>"7274.33",
#    "indicator"=>"A",
#    "zip_code"=>"11187",
#    "latest_address"=>
#     {"veteran_name"=>"Cristy Leannon",
#      "address1"=>"1604 Daniel Points",
#      "address2"=>nil,
#      "address3"=>nil,
#      "address4"=>nil,
#      "address5"=>nil,
#      "city"=>"New Shelton",
#      "state"=>"NV",
#      "zip_code"=>"11187",
#      "origin"=>"backend"},
#    "pending_documents"=>[{"doc_type"=>"quia", "queue_date"=>"2024-07-19"}, {"doc_type"=>"adipisci", "queue_date"=>"2024-07-19"}, {"doc_type"=>"eum", "queue_date"=>"2024-07-16"}],
#    "verifications"=>[],
#    "pending_verifications"=>[]}}
