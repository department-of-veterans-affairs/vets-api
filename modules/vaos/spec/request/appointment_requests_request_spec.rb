# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos appointment requests', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

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
