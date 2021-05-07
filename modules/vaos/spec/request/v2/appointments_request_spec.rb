# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'vaos appointments', type: :request, skip_mvi: true do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'loa3 user' do
    let(:current_user) { build(:user, :vaos) }

    describe 'GET appointments' do
      let(:start_date) { Time.zone.parse('2020-06-02T07:00:00Z') }
      let(:end_date) { Time.zone.parse('2020-07-02T08:00:00Z') }
      let(:params) { { start_date: start_date, end_date: end_date } }

      context 'returns list of appointments' do
        it 'has access and returns va appointments' do
          VCR.use_cassette('vaos/v2/appointments/get_appointments', match_requests_on: %i[method uri]) do
            get '/vaos/v2/appointments', params: params

            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].size).to eq(1)
            expect(response).to match_response_schema('vaos/v2/appointments', { strict: false })
          end
        end
      end
    end
  end
end
