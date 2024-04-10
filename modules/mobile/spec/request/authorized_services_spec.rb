# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'

RSpec.describe 'user', type: :request do
  let!(:user) { sis_user }
  let(:attributes) { response.parsed_body.dig('data', 'attributes') }

  before { Flipper.enable('va_online_scheduling') }

  describe 'GET /mobile/v0/user/authorized-services' do
    it 'includes a hash with all available services and a boolean value of if the user has access' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      expect(response).to have_http_status(:ok)

      expect(attributes['authorizedServices']).to eq(
        { 'appeals' => true,
          'appointments' => true,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => true,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => true,
          'prescriptions' => false,
          'scheduleAppointments' => false,
          'secureMessaging' => false,
          'userProfileUpdate' => true }
      )
    end
  end
end
