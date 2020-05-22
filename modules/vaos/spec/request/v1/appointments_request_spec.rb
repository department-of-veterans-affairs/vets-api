# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appointment', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/vaos/v1/Appointment'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['issue'].first.dig('details', 'text'))
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :vaos) }

    describe 'GET /vaos/v1/Appointment?queries' do
      context 'with a no query string' do
        it 'returns a 200' do
          get '/vaos/v1/Appointment'

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
