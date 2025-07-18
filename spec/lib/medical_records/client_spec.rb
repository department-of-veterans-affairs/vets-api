# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client'
require 'stringio'

describe MedicalRecords::Client do
  context 'using API Gateway endpoints' do
    context 'when a valid session exists', :vcr do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_support_new_model_allergy).and_return(false)

        VCR.use_cassette('user_eligibility_client/apigw_perform_an_eligibility_check_for_premium_user',
                         match_requests_on: %i[method sm_user_ignoring_path_param]) do
          VCR.use_cassette 'mr_client/apigw_session' do
            VCR.use_cassette 'mr_client/apigw_get_a_patient_by_identifier' do
              @client ||= begin
                client = MedicalRecords::Client.new(session: { user_id: '22406991', icn: '1013868614V792025' })
                client.authenticate
                client
              end
            end
          end
        end

        MedicalRecords::Client.send(:public, *MedicalRecords::Client.protected_instance_methods)

        # Redirect FHIR logger's output to the buffer before each test
        @original_output = FHIR.logger.instance_variable_get(:@logdev).dev
        FHIR.logger.instance_variable_set(:@logdev, Logger::LogDevice.new(info_log_buffer))
      end

      after do
        MedicalRecords::Client.send(:protected, *MedicalRecords::Client.protected_instance_methods)

        # Restore original logger output after each test
        FHIR.logger.instance_variable_set(:@logdev, Logger::LogDevice.new(@original_output))
      end

      let(:client) { @client }
      let(:entries) { ['Entry 1', 'Entry 2', 'Entry 3', 'Entry 4', 'Entry 5'] }
      let(:info_log_buffer) { StringIO.new }

      it 'gets a list of allergies', :vcr do
        VCR.use_cassette 'mr_client/apigw_get_a_list_of_allergies' do
          allergy_list = client.list_allergies('uuid')
          expect(
            a_request(:any, //).with(headers: { 'Cache-Control' => 'no-cache' })
          ).to have_been_made.at_least_once
          expect(allergy_list).to be_a(FHIR::Bundle)
          expect(info_log_buffer.string).not_to include('2952')
          # Verify that the list is sorted reverse chronologically (with nil values to the end).
          allergy_list.entry.each_cons(2) do |prev, curr|
            prev_date = prev.resource.recordedDate
            curr_date = curr.resource.recordedDate
            expect(curr_date.nil? || prev_date >= curr_date).to be true
          end
        end
      end
    end
  end
end
