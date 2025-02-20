# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe 'Vye::V1::Verify#create', type: :request do
  let!(:current_user) { create(:user, :accountable) }

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

    describe 'where the request is coming from a user logged into the website and' do
      describe 'is not in VYE' do
        it 'does not accept the request' do
          post('/vye/v1/verify', params: {})
          expect(response).to have_http_status(:forbidden)
        end
      end

      # TODO: Figure out why the olive_branch_patch does not like passing in json with multiple award_ids
      describe 'in VYE' do
        let(:cur_award_ind) { Vye::Award.cur_award_inds[:future] }
        let(:now) { Time.parse('2024-03-31T12:00:00-00:00') }
        let(:date_last_certified) { Date.new(2024, 2, 15) }
        let(:last_day_of_previous_month) { Date.new(2024, 2, 29) } # This is not used only for documentation
        let(:award_begin_date) { Date.new(2024, 3, 30) }
        let(:today) { Date.new(2024, 3, 31) } # This is not used only for documentation
        let(:award_end_date) { Date.new(2024, 4, 1) }
        let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
        let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
        let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }
        let(:award_ids) { user_info.awards.pluck(:id) }

        let(:headers) { { 'Content-Type' => 'application/json', 'X-Key-Inflection' => 'camel' } }

        let(:params) do
          { award_ids: }
            .deep_transform_keys! { |key| key.to_s.camelize(:lower) }
            .slice('awardIds')
            .to_json
        end

        before do
          Timecop.travel(now)
        end

        after do
          Timecop.return
        end

        it 'creates a new verification' do
          post('/vye/v1/verify', headers:, params:)

          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
