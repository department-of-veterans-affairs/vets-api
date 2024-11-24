# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::User::AuthorizedServices', type: :request do
  include CommitteeHelper

  let!(:user) { sis_user(vha_facility_ids: [402, 555]) }
  let(:attributes) { response.parsed_body.dig('data', 'attributes') }

  describe 'GET /mobile/v0/user/authorized-services' do
    it 'includes a hash with all available services and a boolean value of if the user has access' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)

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
