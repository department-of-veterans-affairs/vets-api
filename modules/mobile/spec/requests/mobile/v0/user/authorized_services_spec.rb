# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
RSpec.describe 'Mobile::V0::User::AuthorizedServices', type: :request do
  let!(:user) { sis_user(vha_facility_ids: [402, 555]) }
  let(:attributes) { response.parsed_body.dig('data', 'attributes') }

  describe 'GET /mobile/v0/user/authorized-services' do
    before do
      allow(Settings.mhv).to receive(:facility_range).and_return([[1, 999]])
    end

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
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true }
      )
    end
  end
end
