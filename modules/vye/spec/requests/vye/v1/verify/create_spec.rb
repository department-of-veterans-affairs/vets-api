# frozen_string_literal: true

require_relative '../../../../rails_helper'

RSpec.describe Vye::V1::VerificationsController, type: :request do
  let!(:current_user) { create(:user, :loa3) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe 'POST /vye/v1/verify with flag turned off' do
    before do
      Flipper.disable :vye_request_allowed
    end

    it 'does not accept the request' do
      post('/vye/v1/verify', params: {})
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /vye/v1/verify with flag turned on' do
    before do
      Flipper.enable :vye_request_allowed
    end

    describe 'where current_user is' do
      describe 'not in VYE' do
        it 'does not accept the request' do
          post('/vye/v1/verify', params: {})
          expect(response).to have_http_status(:forbidden)
        end
      end

      describe 'in VYE' do
        let!(:user_profile) { FactoryBot.create(:vye_user_profile, icn: current_user.icn) }
        let!(:user_info) { FactoryBot.create(:vye_user_info, user_profile:) }
        let!(:award) { FactoryBot.create(:vye_award, user_info:) }

        it 'creates a new verification' do
          post('/vye/v1/verify', params: {})

          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'where the request is coming from IVR' do
      let(:ivr_key) { Vye.settings.ivr_key }
      let(:file_number) { '123456789' }

      let!(:user_profile) { FactoryBot.create(:vye_user_profile, file_number:) }
      let!(:user_info) { FactoryBot.create(:vye_user_info, user_profile:) }
      let!(:award) { create(:vye_award, user_info:) }

      let(:award_ids) { user_info.awards.pluck(:id) }

      let(:ivr_params) { { ivr_key:, file_number:, award_ids: } }

      it 'creates a new verification' do
        post('/vye/v1/verify', params: ivr_params)

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
