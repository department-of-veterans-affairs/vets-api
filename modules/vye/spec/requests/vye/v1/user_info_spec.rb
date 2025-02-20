# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe 'Vye::V1 UserInfo', type: :request do
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
          let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
          let!(:user_info) { create(:vye_user_info, user_profile:) }

          it 'returns the user_info' do
            get '/vye/v1'

            json = JSON.parse(response.body)

            expect(json['vye/user_info']).to be_present

            %w[cert_issue_date del_date date_last_certified].each do |attribute|
              expect(json['vye/user_info'][attribute]).to eq user_info.send(attribute.to_sym).to_s
            end

            expected_veteran_name = user_info.latest_address.veteran_name
            expect(json['vye/user_info'].keys).to include('latest_address')
            expect(json['vye/user_info']['latest_address']['veteran_name']).to eq expected_veteran_name

            expect_doc_type = user_info.pending_documents.first.doc_type
            expect_queue_date = user_info.pending_documents.first.queue_date.to_s
            expect(json['vye/user_info']['pending_documents'].class).to eq Array
            expect(json['vye/user_info']['pending_documents'][0]['doc_type']).to eq expect_doc_type
            expect(json['vye/user_info']['pending_documents'][0]['queue_date']).to eq expect_queue_date

            expect(json['vye/user_info']['verifications'].class).to eq Array
            expect(json['vye/user_info']['pending_verifications'].class).to eq Array

            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end
end
