# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos appointments', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'loa1 user with flipper enabled' do
    let(:current_user) { build(:user, :loa1) }

    it 'does not have access' do
      get '/v0/vaos/appointments'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'loa3 user' do
    let(:current_user) { build(:user, :mhv) }
    let(:start_date) { Time.zone.parse('2019-11-14T07:00:00Z') }
    let(:end_date) { Time.zone.parse('2020-03-14T08:00:00Z') }
    let(:params) { { type: 'va', start_date: start_date, end_date: end_date } }

    context 'with flipper disabled' do
      it 'does not have access' do
        Flipper.disable('va_online_scheduling')
        get '/v0/vaos/appointments'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'without icn', skip_mvi: true do
      before { stub_mvi_not_found }

      let(:current_user) { build(:user, :mhv, mhv_icn: nil) }

      it 'does not have access' do
        get '/v0/vaos/appointments'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('No patient ICN found')
      end
    end

    context 'without a type' do
      it 'has a parameter missing exception' do
        get '/v0/vaos/appointments', params: params.except(:type)
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('The required parameter "type", is missing')
      end
    end

    context 'without a start_date' do
      it 'has a parameter missing exception' do
        get '/v0/vaos/appointments', params: params.except(:start_date)
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('The required parameter "start_date", is missing')
      end
    end

    context 'without an end_date' do
      it 'has a parameter missing exception' do
        get '/v0/vaos/appointments', params: params.except(:end_date)
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('The required parameter "end_date", is missing')
      end
    end

    context 'with an invalid type' do
      it 'has an invalid field type exception' do
        get '/v0/vaos/appointments', params: params.merge(type: 'invalid')
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('"invalid" is not a valid value for "type"')
      end
    end

    context 'with an invalid start_date' do
      it 'has an invalid field type exception' do
        get '/v0/vaos/appointments', params: params.merge(start_date: 'invalid')
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('"invalid" is not a valid value for "start_date"')
      end
    end

    context 'with an invalid end_date' do
      it 'has an invalid field type exception' do
        get '/v0/vaos/appointments', params: params.merge(end_date: 'invalid')
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('"invalid" is not a valid value for "end_date"')
      end
    end

    it 'has access and returns va appointments' do
      VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
        get '/v0/vaos/appointments', params: params

        expect(response).to have_http_status(:success)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('vaos/va_appointments')
      end
    end

    it 'has access and returns cc appointments' do
      VCR.use_cassette('vaos/appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
        get '/v0/vaos/appointments', params: params.merge(type: 'cc')

        expect(response).to have_http_status(:success)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('vaos/cc_appointments')
      end
    end
  end
end
