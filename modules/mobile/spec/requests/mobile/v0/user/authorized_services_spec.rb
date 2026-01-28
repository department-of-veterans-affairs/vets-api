# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::User::AuthorizedServices', type: :request do
  include CommitteeHelper
  include JsonSchemaMatchers

  let!(:user) { sis_user(vha_facility_ids: [402, 555]) }
  let(:attributes) { response.parsed_body.dig('data', 'attributes') }
  let(:meta) { response.parsed_body['meta'] }

  describe 'GET /mobile/v0/user/authorized-services' do
    before do
      allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_letter_ready_push_notifications, instance_of(Flipper::Actor)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_allergies_enabled,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_enabled,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_oh_migration_schedules,
                                                instance_of(User)).and_return(false)
    end

    it 'includes a hash with all available services and a boolean value of if the user has access' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(attributes['authorizedServices']).to eq(
        { 'allergiesOracleHealthEnabled' => false,
          'appeals' => true,
          'appointments' => true,
          'benefitsPushNotification' => false,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => true,
          'labsAndTestsEnabled' => false,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => true,
          'prescriptions' => false,
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true,
          'secureMessagingOracleHealthEnabled' => false,
          'medicationsOracleHealthEnabled' => false }
      )
    end

    it 'includes properly set meta flags for user not at pretransitioned oh facility' do
      Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities = '612, 357'
      Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert = '456, 789'
      Settings.mhv.oh_facility_checks.oh_migrations_list = ''
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')
      expect(meta).to eq({ 'isUserAtPretransitionedOhFacility' => false,
                           'isUserFacilityReadyForInfoAlert' => false,
                           'migratingFacilitiesList' => [] })
    end

    it 'includes properly set meta flags for user at pretransitioned oh facility but not ready for info alert' do
      Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities = '612, 357, 555'
      Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert = '456, 789'
      Settings.mhv.oh_facility_checks.oh_migrations_list = ''
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(meta).to eq({
                           'isUserAtPretransitionedOhFacility' => true,
                           'isUserFacilityReadyForInfoAlert' => false,
                           'migratingFacilitiesList' => []
                         })
    end

    it 'includes properly set meta flags for user at pretransitioned oh facility and ready for info alert' do
      Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities = '612, 357, 555'
      Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert = '555'
      Settings.mhv.oh_facility_checks.oh_migrations_list = ''
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(meta).to eq({
                           'isUserAtPretransitionedOhFacility' => true,
                           'isUserFacilityReadyForInfoAlert' => true,
                           'migratingFacilitiesList' => []
                         })
    end

    it 'includes properly set meta flags for actively migrating facility' do
      Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities = '612, 357'
      Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert = '612'
      Settings.mhv.oh_facility_checks.oh_migrations_list = '2026-10-01:[555,Facility A],[612,Facility B]'
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(meta).to eq({
                           'isUserAtPretransitionedOhFacility' => false,
                           'isUserFacilityReadyForInfoAlert' => false,
                           'migratingFacilitiesList' => []
                         })
    end
  end

  describe 'when event_bus_gateway_letter_ready_push_notifications flag is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_letter_ready_push_notifications, instance_of(Flipper::Actor)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_allergies_enabled,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                instance_of(User)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_enabled,
                                                instance_of(User)).and_return(false)
    end

    it 'includes benefitsPushNotification when user has ICN' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)

      expect(attributes['authorizedServices']['benefitsPushNotification']).to be true
    end

    context 'when user has no ICN' do
      let!(:user) { sis_user(vha_facility_ids: [402, 555], icn: nil) }

      it 'excludes benefitsPushNotification' do
        get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                   params: { 'appointmentIEN' => '123', 'locationId' => '123' }
        assert_schema_conform(200)

        expect(attributes['authorizedServices']['benefitsPushNotification']).to be false
      end
    end
  end

  describe 'when OH flippers are enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:event_bus_gateway_letter_ready_push_notifications, instance_of(Flipper::Actor)).and_return(false)
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_cerner_pilot, instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot,
                                                instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_allergies_enabled,
                                                instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_enabled,
                                                instance_of(User)).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_oh_migration_schedules,
                                                instance_of(User)).and_return(true)
    end

    it 'includes a hash with only some OH services enabled if app version matches' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers({ 'App-Version' => '2.99.99' }),
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(attributes['authorizedServices']).to eq(
        { 'allergiesOracleHealthEnabled' => false,
          'appeals' => true,
          'appointments' => true,
          'benefitsPushNotification' => false,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => true,
          'labsAndTestsEnabled' => false,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => true,
          'prescriptions' => false,
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true,
          'secureMessagingOracleHealthEnabled' => true,
          'medicationsOracleHealthEnabled' => true }
      )
    end

    it 'includes a hash with all OH services enabled if app version is high enough' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers({ 'App-Version' => '3.0.0' }),
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(attributes['authorizedServices']).to eq(
        { 'allergiesOracleHealthEnabled' => true,
          'appeals' => true,
          'appointments' => true,
          'benefitsPushNotification' => false,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => true,
          'labsAndTestsEnabled' => true,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => true,
          'prescriptions' => false,
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true,
          'secureMessagingOracleHealthEnabled' => true,
          'medicationsOracleHealthEnabled' => true }
      )
    end

    it 'includes a hash with all OH services disabled if Big Red Button(TM) is disabled' do
      allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_enabled,
                                                instance_of(User)).and_return(false)
      get '/mobile/v0/user/authorized-services', headers: sis_headers({ 'App-Version' => '3.0.0' }),
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(attributes['authorizedServices']).to eq(
        { 'allergiesOracleHealthEnabled' => false,
          'appeals' => true,
          'appointments' => true,
          'benefitsPushNotification' => false,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => true,
          'labsAndTestsEnabled' => false,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => true,
          'prescriptions' => false,
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true,
          'secureMessagingOracleHealthEnabled' => true,
          'medicationsOracleHealthEnabled' => false }
      )
    end

    it 'includes a hash with all OH services disabled if app version is not high enough' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers({ 'App-Version' => '2.0.0' }),
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(attributes['authorizedServices']).to eq(
        { 'allergiesOracleHealthEnabled' => false,
          'appeals' => true,
          'appointments' => true,
          'benefitsPushNotification' => false,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => true,
          'labsAndTestsEnabled' => false,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => true,
          'prescriptions' => false,
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true,
          'secureMessagingOracleHealthEnabled' => true,
          'medicationsOracleHealthEnabled' => false }
      )
    end

    it 'includes a hash with all OH services disabled if app version not in headers' do
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(attributes['authorizedServices']).to eq(
        { 'allergiesOracleHealthEnabled' => false,
          'appeals' => true,
          'appointments' => true,
          'benefitsPushNotification' => false,
          'claims' => true,
          'decisionLetters' => true,
          'directDepositBenefits' => true,
          'directDepositBenefitsUpdate' => true,
          'disabilityRating' => true,
          'genderIdentity' => true,
          'labsAndTestsEnabled' => false,
          'lettersAndDocuments' => true,
          'militaryServiceHistory' => true,
          'paymentHistory' => true,
          'preferredName' => true,
          'prescriptions' => false,
          'scheduleAppointments' => true,
          'secureMessaging' => false,
          'userProfileUpdate' => true,
          'secureMessagingOracleHealthEnabled' => true,
          'medicationsOracleHealthEnabled' => false }
      )
    end

    it 'includes properly sets migratingFacilitiesList when user does not have a migrating facility' do
      Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities = '612, 357'
      Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert = '612'
      Settings.mhv.oh_facility_checks.oh_migrations_list = '2026-10-01:[999,Facility A],[888,Facility B]'
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(meta['migratingFacilitiesList']).to eq([])
    end

    it 'includes properly sets migratingFacilitiesList when user does have a migrating facility' do
      Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities = '612, 357'
      Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert = '612'
      Settings.mhv.oh_facility_checks.oh_migrations_list = '2026-10-01:[555,Facility A],[555,Facility B]'
      get '/mobile/v0/user/authorized-services', headers: sis_headers,
                                                 params: { 'appointmentIEN' => '123', 'locationId' => '123' }
      assert_schema_conform(200)
      expect(response.body).to match_json_schema('authorized_services')

      expect(meta['migratingFacilitiesList'].length).to eq(1)
      expect(meta.dig('migratingFacilitiesList', 0, 'migrationDate')).to eq('October 1, 2026')
      expect(meta.dig('migratingFacilitiesList', 0, 'facilities').length).to eq(2)
    end
  end
end
