# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/LineLength
RSpec.describe 'vaos appointments', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
  end

  context 'loa1 user with flipper enabled' do
    let(:current_user) { build(:user, :loa1) }

    it 'should not have access' do
      get '/services/vaos/v0/appointments'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'loa3 user' do
    let(:current_user) { build(:user, :dslogon) }
    let(:date_range) { { start_date: '2019-09-04T07:00:00Z', end_date: '2020-01-04T08:00:00Z' } }

    context 'with flipper disabled' do
      it 'should not have access' do
        Flipper.disable('va_online_scheduling')
        get '/services/vaos/v0/appointments'
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'without a date range' do
      it 'should have a parameter missing exception' do
        get '/services/vaos/v0/appointments'
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('The required parameter "start_date", is missing')
      end
    end

    it 'should have access and return appointments with size 1' do
      VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[host path method]) do
        get '/services/vaos/v0/appointments', params: date_range

        expect(response).to have_http_status(:success)
        expect(response.body).to be_a(String)
        binding.pry
        expect(response).to match_response_schema('vaos/va_appointments')
      end
    end
  end
end
