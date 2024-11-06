# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'

Rspec.describe ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController, type: :request do
  include ClaimsApi::Engine.routes.url_helpers

  describe '#index' do
    let(:scopes) { %w[claim.read] }

    it 'raises a ParameterMissing error if poaCodes is not present' do
      expect do
        subject.index
      end.to raise_error(Common::Exceptions::ParameterMissing)
    end

    context 'when poaCodes is present but empty' do
      before do
        allow(subject).to receive(:form_attributes).and_return({ 'poaCodes' => [] })
      end

      it 'raises a ParameterMissing error' do
        expect do
          subject.index
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when poaCodes is present and valid' do
      let(:poa_codes) { %w[002 003 083] }

      it 'returns a list of claimants' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_valid') do
            index_request_with(poa_codes:, auth_header:)

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body).size).to eq(3)
          end
        end
      end
    end

    context 'when poaCodes is present but no records are found' do
      let(:poa_codes) { %w[XYZ] }

      it 'raises a ResourceNotFound error' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_not_found') do
            index_request_with(poa_codes:, auth_header:)

            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end
  end

  describe '#decide' do
    let(:scopes) { %w[claim.write] }

    it 'raises a ParameterMissing error if procId is not present' do
      expect do
        subject.decide
      end.to raise_error(Common::Exceptions::ParameterMissing)
    end

    context 'when decision is not present' do
      before do
        allow(subject).to receive(:form_attributes).and_return({ 'procId' => '76529' })
      end

      it 'raises a ParameterMissing error if decision is not present' do
        expect do
          subject.decide
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when decision is not ACCEPTED or DECLINED' do
      before do
        allow(subject).to receive(:form_attributes).and_return({ 'procId' => '76529', 'decision' => 'invalid' })
      end

      it 'raises a ParameterMissing error' do
        expect do
          subject.decide
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when procId is present and valid and decision is accepted' do
      let(:proc_id) { '76529' }
      let(:decision) { 'ACCEPTED' }

      it 'updates the secondaryStatus and returns a hash containing the ACC code' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
            decide_request_with(proc_id:, decision:, auth_header:)

            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['procId']).to eq(proc_id)
            expect(response_body['secondaryStatus']).to eq('ACC')
          end
        end
      end
    end

    context 'when procId is present but invalid' do
      let(:proc_id) { '1' }
      let(:decision) { 'ACCEPTED' }

      it 'raises an error' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_not_found') do
            decide_request_with(proc_id:, decision:, auth_header:)

            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end
    end
  end

  describe '#create' do
    let(:scopes) { %w[claim.write] }
    let(:form_attributes) do
      {
        veteran: {
          service_number: '123678453',
          service_branch: 'ARMY',
          address: {
            address_line1: '2719 Hyperion Ave',
            address_line2: 'Apt 2',
            city: 'Los Angeles',
            country: 'USA',
            state_code: 'CA',
            zip_code: '92264',
            zip_code_suffix: '0200'
          },
          phone: {
            area_code: '555',
            phone_number: '5551234'
          },
          email: 'test@test.com',
          insurance_number: '1234567890'
        },
        poa: {
          poa_code: '003',
          registration_number: '12345',
          job_title: 'MyJob'
        },
        record_consent: true,
        consent_address_change: true,
        consent_limits: %w[
          DRUG_ABUSE
          SICKLE_CELL
          HIV
          ALCOHOLISM
        ]
      }
    end
    let(:veteran_id) { '1012667145V762142' }
    let(:representative_data) do
      {
        'poa' => {
          'firstName' => 'John',
          'lastName' => 'Doe'
        }
      }
    end
    let(:terminate_existing_requests) do
      instance_double(ClaimsApi::PowerOfAttorneyRequestService::TerminateExistingRequests)
    end
    let(:create_request) do
      instance_double(ClaimsApi::PowerOfAttorneyRequestService::CreateRequest)
    end
    let(:create_request_response) do
      {
        'addressLine1' => '2719 Hyperion Ave',
        'addressLine2' => 'Apt 2',
        'addressLine3' => nil,
        'changeAddressAuth' => 'true',
        'city' => 'Los Angeles',
        'claimantPtcpntId' => '185953',
        'claimantRelationship' => nil,
        'formTypeCode' => '21-22',
        'insuranceNumbers' => '1234567890',
        'limitationAlcohol' => 'true',
        'limitationDrugAbuse' => 'true',
        'limitationHIV' => 'true',
        'limitationSCA' => 'true',
        'organizationName' => nil,
        'otherServiceBranch' => nil,
        'phoneNumber' => '5555551234',
        'poaCode' => '003',
        'postalCode' => '92264',
        'procId' => '3857415',
        'representativeFirstName' => nil,
        'representativeLastName' => nil,
        'representativeLawFirmOrAgencyName' => nil,
        'representativeTitle' => 'MyJob',
        'representativeType' => 'Recognized Veterans Service Organization',
        'section7332Auth' => 'true',
        'serviceBranch' => 'Army',
        'serviceNumber' => '123678453',
        'state' => 'CA',
        'vdcStatus' => 'Submitted',
        'veteranPtcpntId' => '185953',
        'acceptedBy' => nil,
        'claimantFirstName' => 'TAMARA',
        'claimantLastName' => 'ELLIS',
        'claimantMiddleName' => nil,
        'declinedBy' => nil,
        'declinedReason' => nil,
        'secondaryStatus' => nil,
        'veteranFirstName' => 'TAMARA',
        'veteranLastName' => 'ELLIS',
        'veteranMiddleName' => nil,
        'veteranSSN' => '796130115',
        'veteranVAFileNumber' => '00123456'
      }
    end

    before do
      allow_any_instance_of(ClaimsApi::FormSchemas).to receive(:validate!).and_return(nil)
      allow_any_instance_of(described_class).to receive(:validate_accredited_representative)
        .with(anything, anything)
        .and_return(nil)
      allow_any_instance_of(described_class).to receive(:validate_accredited_organization)
        .with(anything)
        .and_return(nil)
      allow_any_instance_of(described_class).to receive(:representative_data).and_return(representative_data)
      Flipper.disable(:lighthouse_claims_v2_poa_requests_skip_bgs)
      allow(ClaimsApi::PowerOfAttorneyRequestService::TerminateExistingRequests).to receive(:new)
        .with(anything)
        .and_return(terminate_existing_requests)
      allow(terminate_existing_requests).to receive(:call).and_return(nil)
      allow(ClaimsApi::PowerOfAttorneyRequestService::CreateRequest).to receive(:new)
        .with(anything, anything, anything, anything)
        .and_return(create_request)
      allow(create_request).to receive(:call).and_return(create_request_response)
    end

    it 'returns a created status and procId in the response' do
      mock_ccg(scopes) do |auth_header|
        create_request_with(veteran_id:, form_attributes:, auth_header:)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['data']['attributes']['procId']).to eq('3857415')
      end
    end
  end

  def index_request_with(poa_codes:, auth_header:)
    post v2_veterans_power_of_attorney_requests_path,
         params: { data: { attributes: { poaCodes: poa_codes } } }.to_json,
         headers: auth_header
  end

  def decide_request_with(proc_id:, decision:, auth_header:)
    post v2_veterans_power_of_attorney_requests_decide_path,
         params: { data: { attributes: { procId: proc_id, decision: } } }.to_json,
         headers: auth_header
  end

  def create_request_with(veteran_id:, form_attributes:, auth_header:)
    post "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney-request",
         params: { data: { attributes: form_attributes } }.to_json,
         headers: auth_header
  end
end
