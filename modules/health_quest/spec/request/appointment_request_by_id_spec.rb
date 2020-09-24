# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'health_quest appointments', type: :request, skip_mvi: true do
  include SchemaMatchers

  before do
    Flipper.enable('show_healthcare_experience_questionnaire')
    sign_in_as(current_user)
    allow_any_instance_of(HealthQuest::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'loa3 user' do
    let(:current_user) { build(:user, :health_quest) }

    describe 'GET appointments' do
      it 'has access and returns va appointments' do
        VCR.use_cassette('health_quest/appointments/get_appointment_by_id', match_requests_on: %i[method uri]) do
          get '/health_quest/v0/appointments/132'
          appointment_attr = JSON.parse(response.body)['data']['attributes']
          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(appointment_attr['clinic_id']).to eq('848')
          expect(appointment_attr['clinic_friendly_name']).to eq('CHY PC VAR2')
        end
      end
    end
  end
end
