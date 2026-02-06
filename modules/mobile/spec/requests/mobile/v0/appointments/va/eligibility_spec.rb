# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require_relative '../../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Appointments::VA::Eligibility', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '9000682') }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, instance_of(User)).and_return(false)
  end

  describe 'GET /mobile/v0/appointments/va/eligibility' do
    context 'valid params' do
      context 'one facility' do
        let(:params) { { facilityIds: ['489'] } }
        let(:services_response) do
          [{ 'name' => 'amputation',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => [] },
           { 'name' => 'audiology',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'covid',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'optometry',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'outpatientMentalHealth',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'moveProgram',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'foodAndNutrition',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'clinicalPharmacyPrimaryCare',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'podiatry',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => [] },
           { 'name' => 'primaryCare',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => [] },
           { 'name' => 'homeSleepTesting',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'socialWork',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'cpap',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'ophthalmology',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] }]
        end

        context 'with CSCS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(true)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_cscs_200',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'response properly assigns facilities to services' do
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end

          it 'does not include non-cc supported facility in cc_supported ids' do
            cc_supported_facility_ids = response.parsed_body.dig('data', 'attributes', 'ccSupported')

            expect(cc_supported_facility_ids).to eq([])
          end
        end

        context 'with MFS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(false)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_mfs_200',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'response properly assigns facilities to services' do
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end

          it 'does not include non-cc supported facility in cc_supported ids' do
            cc_supported_facility_ids = response.parsed_body.dig('data', 'attributes', 'ccSupported')

            expect(cc_supported_facility_ids).to eq([])
          end
        end
      end

      context 'multiple facilities' do
        let(:params) { { facilityIds: %w[489 984] } }
        let(:services_response) do
          [{ 'name' => 'amputation',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => [] },
           { 'name' => 'audiology',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => %w[489 984] },
           { 'name' => 'covid',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'optometry',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'outpatientMentalHealth',
             'requestEligibleFacilities' => ['984'],
             'directEligibleFacilities' => [] },
           { 'name' => 'moveProgram',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'foodAndNutrition',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => ['984'] },
           { 'name' => 'clinicalPharmacyPrimaryCare',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => ['984'] },
           { 'name' => 'podiatry',
             'requestEligibleFacilities' => %w[489 984],
             'directEligibleFacilities' => [] },
           { 'name' => 'primaryCare',
             'requestEligibleFacilities' => %w[489 984],
             'directEligibleFacilities' => ['984'] },
           { 'name' => 'homeSleepTesting',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'socialWork',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'cpap',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'ophthalmology',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] }]
        end

        context 'with CSCS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(true)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_cscs_200',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'response properly assigns facilities to services' do
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end

          it 'groups cc_supported ids' do
            cc_supported_facility_ids = response.parsed_body.dig('data', 'attributes', 'ccSupported')

            expect(cc_supported_facility_ids).to eq(%w[984])
          end
        end

        context 'with MFS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(false)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_mfs_200',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'response properly assigns facilities to services' do
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end

          it 'groups cc_supported ids' do
            cc_supported_facility_ids = response.parsed_body.dig('data', 'attributes', 'ccSupported')
            # binding.pry

            expect(cc_supported_facility_ids).to eq(%w[984])
          end
        end
      end

      context 'all services enabled' do
        let(:params) { { facilityIds: ['489'] } }
        let(:services_response) do
          [{ 'name' => 'amputation',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'audiology',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'covid',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'optometry',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'outpatientMentalHealth',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'moveProgram',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'foodAndNutrition',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' =>
              'clinicalPharmacyPrimaryCare',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'podiatry',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'primaryCare',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'homeSleepTesting',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'socialWork',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'cpap',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] },
           { 'name' => 'ophthalmology',
             'requestEligibleFacilities' => ['489'],
             'directEligibleFacilities' => ['489'] }]
        end

        context 'with CSCS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(true)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_cscs_200_all_enabled',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'all service ids are hit when parsing upstream response except for covid request' do
            # this is used to ensure that all the service ids in the parser are all matching to
            # something in the response.
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end
        end

        context 'with MFS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(false)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_mfs_200_all_enabled',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'all service ids are hit when parsing upstream response except for covid request' do
            # this is used to ensure that all the service ids in the parser are all matching to
            # something in the response.
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end
        end
      end

      context 'bad facility' do
        let(:params) { { facilityIds: ['12345678'] } }
        let(:services_response) do
          [{ 'name' => 'amputation',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'audiology',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'covid',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'optometry',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'outpatientMentalHealth',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'moveProgram',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'foodAndNutrition',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'clinicalPharmacyPrimaryCare',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'podiatry',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'primaryCare',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'homeSleepTesting',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'socialWork',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'cpap',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] },
           { 'name' => 'ophthalmology',
             'requestEligibleFacilities' => [],
             'directEligibleFacilities' => [] }]
        end

        context 'with CSCS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(true)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_cscs_200_bad_facility',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'upstream service does not check for valid facility and returns no eligibility' do
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end

          it 'does not include any cc_supported ids' do
            cc_supported_facility_ids = response.parsed_body.dig('data', 'attributes', 'ccSupported')

            expect(cc_supported_facility_ids).to eq(%w[])
          end
        end

        context 'with MFS' do
          before do
            allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_cscs_migration,
                                                      instance_of(User)).and_return(false)
            VCR.use_cassette('mobile/va_eligibility/get_scheduling_configurations_mfs_200_bad_facility',
                             match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments/va/eligibility', params:, headers: sis_headers
            end
          end

          it 'returns successful response' do
            expect(response).to have_http_status(:success)
          end

          it 'matches schema' do
            expect(response.body).to match_json_schema('service_eligibility')
          end

          it 'upstream service does not check for valid facility and returns no eligibility' do
            services = response.parsed_body.dig('data', 'attributes', 'services')

            expect(services).to eq(services_response)
          end

          it 'does not include any cc_supported ids' do
            cc_supported_facility_ids = response.parsed_body.dig('data', 'attributes', 'ccSupported')

            expect(cc_supported_facility_ids).to eq(%w[])
          end
        end
      end
    end

    context 'invalid params' do
      before do
        get '/mobile/v0/appointments/va/eligibility', params: nil, headers: sis_headers
      end

      it 'returns 400 response' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'error for missing parameter' do
        expect(response.parsed_body).to eq({ 'errors' =>
                                              [{ 'title' => 'Missing parameter',
                                                 'detail' =>
                                                  'The required parameter "facilityIds", is missing',
                                                 'code' => '108',
                                                 'status' => '400' }] })
      end
    end
  end
end
