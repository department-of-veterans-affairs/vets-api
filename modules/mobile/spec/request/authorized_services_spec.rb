# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'

RSpec.describe 'user', type: :request do
  let(:attributes) { response.parsed_body.dig('data', 'attributes') }

  describe 'GET /mobile/v0/user/authorized-services' do
    before do
      iam_sign_in(FactoryBot.build(:iam_user))
    end

    it 'includes a hash with all available services and a boolean value of if the user has access' do
      get '/mobile/v0/user/authorized-services', headers: iam_headers
      expect(response).to have_http_status(:ok)

      expect(attributes['authorizedServices']).to eq(
        { 'appeals' => true,
          'appointments' => true,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => false,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => false,
          'prescriptions' => false,
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true }
      )
    end
  end
end
