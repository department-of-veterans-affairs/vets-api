# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos appointment requests', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET /v0/vaos/appointment_requests' do
    context 'loa1 user with flipper enabled' do
      let(:current_user) { build(:user, :loa1) }

      it 'does not have access' do
        get '/v0/vaos/appointment_requests'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'loa3 user' do
      let(:current_user) { build(:user, :mhv) }
      let(:start_date) { Date.parse('2019-08-20') }
      let(:end_date) { Date.parse('2020-08-22') }
      let(:params) { { start_date: start_date, end_date: end_date } }

      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          get '/v0/vaos/appointment_requests'
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'without a start_date' do
        it 'has a parameter missing exception' do
          get '/v0/vaos/appointment_requests', params: params.except(:start_date)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "start_date", is missing')
        end
      end

      context 'without an end_date' do
        it 'has a parameter missing exception' do
          get '/v0/vaos/appointment_requests', params: params.except(:end_date)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "end_date", is missing')
        end
      end

      context 'with an invalid start_date' do
        it 'has an invalid field type exception' do
          get '/v0/vaos/appointment_requests', params: params.merge(start_date: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "start_date"')
        end
      end

      context 'with an invalid end_date' do
        it 'has an invalid field type exception' do
          get '/v0/vaos/appointment_requests', params: params.merge(end_date: 'invalid')
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('"invalid" is not a valid value for "end_date"')
        end
      end

      it 'has access and returns va appointments' do
        VCR.use_cassette('vaos/appointment_requests/get_requests_with_params', match_requests_on: %i[method uri]) do
          get '/v0/vaos/appointment_requests', params: params
          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/appointment_requests')
        end
      end
    end
  end

  describe 'POST /v0/vaos/appointment_requests', skip_mvi: true do
    let(:current_user) { build(:user, :vaos) }
    let(:params) { build(:appointment_request_form, :creation, user: current_user).params }

    it 'creates a new appointment request' do
      VCR.use_cassette('vaos/appointment_requests/post_request', match_requests_on: %i[method uri]) do
        post '/v0/vaos/appointment_requests', params: params
        expect(response).to have_http_status(:created)
        expect(response.body).to be_a(String)
        expect(json_body_for(response)).to match_schema('vaos/appointment_request')
      end
    end

    context 'Community Cares' do
      let(:params) { build(:cc_appointment_request_form, :creation, user: current_user).params.merge(type: 'cc') }

      it 'creates a new appointment request' do
        VCR.use_cassette('vaos/appointment_requests/post_request_CC', match_requests_on: %i[method uri]) do
          post '/v0/vaos/appointment_requests', params: params

          expect(response).to have_http_status(:created)
          expect(response.body).to be_a(String)
          expect(json_body_for(response)).to match_schema('vaos/appointment_request')
        end
      end
    end
  end

  describe 'PUT /v0/vaos/appointment_requests/:id', skip_mvi: true do
    let(:current_user) { build(:user, :vaos) }
    let(:id) { '8a4886886e4c8e22016e92be77cb00f9' }
    let(:date) { Time.zone.parse('2019-11-22 10:53:05 +0000') }
    let(:created_date) { '11/22/2019 05:53:0' }
    let(:last_access_date) { nil }
    let(:last_updated_date) { '11/22/2019 05:53:06' }
    let(:params) do
      build(
        :appointment_request_form,
        :cancellation,
        user: current_user,
        id: id,
        date: date,
        created_date: created_date,
        last_access_date: last_access_date,
        last_updated_date:
        last_updated_date
      ).params
    end

    let(:post_params) { params.merge(appointment_request_detail_code: ['DETCODE8']) }

    it 'cancels an appointment request' do
      VCR.use_cassette('vaos/appointment_requests/put_request', match_requests_on: %i[method uri]) do
        put "/v0/vaos/appointment_requests/#{id}", params: params
        expect(response).to have_http_status(:success)
        expect(response.body).to be_a(String)
        expect(json_body_for(response)).to match_schema('vaos/appointment_request')
      end
    end
  end
end
