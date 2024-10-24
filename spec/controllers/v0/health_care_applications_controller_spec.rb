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
    let(:lighthouse_service) { instance_double(Lighthouse::Facilities::V1::Client) }
    let(:unrelated_facility) { Lighthouse::Facilities::Facility.new('id' => 'vha_123', 'attributes' => {}) }
    let(:target_facility) { Lighthouse::Facilities::Facility.new('id' => 'vha_456ab', 'attributes' => {}) }
    let(:deactivated_facility) { Lighthouse::Facilities::Facility.new('id' => 'vha_789', 'attributes' => {}) }
    let(:facilities) { [unrelated_facility, target_facility] }

    before do
      allow(Lighthouse::Facilities::V1::Client).to receive(:new) { lighthouse_service }
      allow(lighthouse_service).to receive(:get_facilities) { facilities }
    end

    it 'only returns facilities in VES' do
      params = { state: 'AK' }

      StdInstitutionFacility.create(station_number: target_facility.unique_id)

      get(:facilities, params:)

      expect(response.body).to eq([target_facility].to_json)
    end

    it 'filters out deactivated facilities' do
      params = { state: 'AK' }

      StdInstitutionFacility.create(station_number: target_facility.unique_id, deactivation_date: nil)
      StdInstitutionFacility.create(station_number: deactivated_facility.unique_id, deactivation_date: Time.current)

      get(:facilities, params:)

      expect(response.body).to eq([target_facility].to_json)
    end

    context 'with hca_retrieve_facilities_without_repopulating disabled' do
      it 'invokes VES import job if query results are empty' do
        allow(Flipper).to receive(:enabled?).with(:hca_retrieve_facilities_without_repopulating).and_return(false)

        params = { state: 'AK' }

        expect(StdInstitutionFacility.all).to eq([])

        import_job = instance_double(HCA::StdInstitutionImportJob)
        expect(HCA::StdInstitutionImportJob).to receive(:new).and_return(import_job)
        expect(import_job).to receive(:perform)

        get(:facilities, params:)
      end
    end

    context 'with hca_retrieve_facilities_without_repopulating enabled' do
      it 'does not invoke VES import job even if query results are empty' do
        allow(Flipper).to receive(:enabled?).with(:hca_retrieve_facilities_without_repopulating).and_return(true)
        params = { state: 'AK' }

        expect(StdInstitutionFacility.all).to eq([])

        expect(HCA::StdInstitutionImportJob).not_to receive(:new)

        get(:facilities, params:)
      end
    end
  end
end
