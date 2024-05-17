# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::V1::UserInfosController, type: :request do
  describe 'GET /vye/v1 with flag turned on' do
    let!(:current_user) { create(:user) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
      Flipper.enable :vye_request_allowed
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

  describe 'where current_user is in VYE from IVR' do
    let(:api_key) { Vye::V1::VerificationsController.send(:api_key_actual) }
    let(:file_number) { '111223333' }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:future] }
    let(:now) { Time.parse('2024-03-31T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2024, 2, 15) }
    let(:last_day_of_previous_month) { Date.new(2024, 2, 29) } # This is not used only for documentation
    let(:award_begin_date) { Date.new(2024, 3, 30) }
    let(:today) { Date.new(2024, 3, 31) } # This is not used only for documentation
    let(:award_end_date) { Date.new(2024, 4, 1) }

    let!(:user_profile) { FactoryBot.create(:vye_user_profile, file_number:) }
    let!(:user_info) { FactoryBot.create(:vye_user_info, user_profile:, date_last_certified:) }
    let!(:address_changes) { FactoryBot.create_list(:vye_address_change, 1, user_info:) }
    let!(:award) { FactoryBot.create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }
    let!(:pending_documents) { FactoryBot.create_list(:vye_pending_document, 1, user_profile:) }

    let(:params) { { api_key:, file_number: } }

    it 'returns the user_info' do
      get('/vye/v1', params:)

      expect(response).to have_http_status(:ok)
    end
  end
end
