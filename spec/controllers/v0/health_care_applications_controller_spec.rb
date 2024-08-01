# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::HealthCareApplicationsController, type: :controller do
  let(:hca_request) { file_fixture('forms/healthcare_application_request.json').read }
  let(:hca_response) { JSON.parse(file_fixture('forms/healthcare_application_response.json').read) }

  describe '#create' do
    it 'creates a pending application' do
      post :create, params: JSON.parse(hca_request)

      json = JSON.parse(response.body)
      expect(json['attributes']).to eq(hca_response['attributes'])
    end
  end

  describe '#facilities' do
    it 'retrieves facilities from Lighthouse, filtered by the list from VES' do
      state_params = { state: 'AK' }

      lighthouse_service = instance_double(Lighthouse::Facilities::V1::Client)
      expect(Lighthouse::Facilities::V1::Client).to receive(:new) { lighthouse_service }

      unrelated_facility = OpenStruct.new(id: 'vha_123')
      target_facility = OpenStruct.new(id: 'vha_456ab')
      facilities_response = [unrelated_facility, target_facility]

      StdInstitutionFacility.create(station_number: '456ab')

      expect(lighthouse_service).to receive(:get_facilities) { facilities_response }

      get :facilities, params: state_params

      expect(response.body).to eq([target_facility].to_json)
    end

    it 'filters out deactivated facilities' do
      state_params = { state: 'AK' }

      lighthouse_service = instance_double(Lighthouse::Facilities::V1::Client)
      expect(Lighthouse::Facilities::V1::Client).to receive(:new) { lighthouse_service }

      unrelated_facility = OpenStruct.new(id: 'vha_123')
      target_facility = OpenStruct.new(id: 'vha_456ab')
      facilities_response = [unrelated_facility, target_facility]

      StdInstitutionFacility.create(station_number: '456ab', deactivation_date: Time.current)

      expect(lighthouse_service).to receive(:get_facilities) { facilities_response }

      get :facilities, params: state_params

      expect(response.body).to eq({ data: [] }.to_json)
    end
  end
end
