# frozen_string_literal: true

require 'rails_helper'
require 'unique_user_events'

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'
require 'support/shared_examples_for_labs_and_tests'

RSpec.describe 'Mobile::V1::LabsAndTestsController', :skip_json_api_validation, type: :request do
  let!(:user) { sis_user(icn: '1000123456V123456') }
  let(:default_params) { { startDate: '2025-01-01', endDate: '2025-09-30' } }
  let(:path) { '/mobile/v1/health/labs-and-tests' }
  let(:labs_cassette) { 'mobile/unified_health_data/get_labs' }
  let(:labs_attachment_cassette) { 'mobile/unified_health_data/get_labs_value_attachment' }
  let(:uhd_flipper) { :mhv_accelerated_delivery_uhd_enabled }

  describe 'GET /mobile/v1/health/labs-and-tests' do
    context 'happy path' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(UniqueUserEvents).to receive(:log_events)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'logs unique user events for labs accessed' do
        expect(UniqueUserEvents).to have_received(:log_events).with(
          user: anything,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_LABS_ACCESSED
          ]
        )
      end

      it 'returns all lab records with encodedData and/or observations' do
        parsed_response = JSON.parse(response.body)
        labs_data = parsed_response['data']
        expect(labs_data).to be_an(Array)
        expect(labs_data.length).to eq(29)

        labs_data.each do |lab_record|
          attributes = lab_record['attributes']
          has_encoded_data = attributes['encodedData'].present?
          has_observations = attributes['observations'].present? && attributes['observations'].any?
          expect(has_encoded_data || has_observations).to be_truthy
        end
      end

      it 'returns the correct count of lab records from cassette' do
        parsed_response = JSON.parse(response.body)
        labs_data = parsed_response['data']
        # The cassette has 29 DiagnosticReports with presentedForm or result
        expect(labs_data.length).to eq(29)
      end
    end

    context 'response structure validation' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      include_examples 'labs and tests response structure validation', ['data']
      include_examples 'labs and tests specific data validation', ['data']
    end

    context 'when UHD is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(false)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a 404 when the flipper is disabled' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'errors' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Rails.logger).to receive(:error)
        VCR.use_cassette(labs_attachment_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns not_implemented when a value attachment is received' do
        expect(Rails.logger).to have_received(:error).with(
          { message: 'Observation with ID 4e0a8d43-1281-4d11-97b8-f77452bea53a has unsupported value type: Attachment' }
        )
        expect(response).to have_http_status(:not_implemented)
      end
    end
  end
end
