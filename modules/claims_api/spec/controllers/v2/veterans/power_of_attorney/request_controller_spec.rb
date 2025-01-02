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

    context 'when pageIndex is present but pageSize is not' do
      before do
        allow(subject).to receive(:form_attributes).and_return({ 'poaCodes' => %w[002 003 083], 'pageIndex' => '2' })
      end

      it 'raises a ParameterMissing error' do
        expect do
          subject.index
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when valid filters are present' do
      let(:filter) do
        { 'status' => %w[New Accepted Declined], 'state' => 'CA', 'city' => 'Cambria', 'country' => 'USA' }
      end
      let(:poa_codes) { %w[002 003 083] }
      let(:mock_bgs_response) do
        {
          'poaRequestRespondReturnVOList' => [
            { 'some_filtered_key' => 'some_filtered_value' }
          ]
        }
      end

      before do
        service_double = instance_double(ClaimsApi::ManageRepresentativeService)
        allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(any_args)
                                                                      .and_return(service_double)
        allow(service_double).to receive(:read_poa_request).with(any_args)
                                                           .and_return(mock_bgs_response)
      end

      it 'returns a successful response' do
        mock_ccg(scopes) do |auth_header|
          index_request_with(poa_codes:, filter:, auth_header:)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when an invalid filter is present' do
      let(:filter) { { 'invalid' => 'invalid' } }
      let(:poa_codes) { %w[002 003 083] }

      it 'raises an UnprocessableEntity error' do
        mock_ccg(scopes) do |auth_header|
          index_request_with(poa_codes:, filter:, auth_header:)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when the status filter is not a list' do
      let(:filter) { { 'status' => 'New' } }
      let(:poa_codes) { %w[002 003 083] }

      it 'raises an UnprocessableEntity error' do
        mock_ccg(scopes) do |auth_header|
          index_request_with(poa_codes:, filter:, auth_header:)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when a filter status is invalid' do
      let(:filter) { { 'status' => %w[New Accepted Declined SomeInvalidStatus] } }
      let(:poa_codes) { %w[002 003 083] }

      it 'raises an UnprocessableEntity error' do
        mock_ccg(scopes) do |auth_header|
          index_request_with(poa_codes:, filter:, auth_header:)

          expect(response).to have_http_status(:unprocessable_entity)
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

    context 'when the decision is declined and a ptcpntId is present' do
      let(:service) { instance_double(ClaimsApi::ManageRepresentativeService) }
      let(:poa_request_response) do
        {
          'poaRequestRespondReturnVOList' => [
            {
              'procID' => '76529',
              'claimantFirstName' => 'John',
              'poaCode' => '123'
            }
          ]
        }
      end
      let(:mock_lockbox) { double('Lockbox', encrypt: 'encrypted value') }

      before do
        allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(anything).and_return(service)
        allow(service).to receive(:read_poa_request_by_ptcpnt_id).with(ptcpnt_id: '123456789')
                                                                 .and_return(poa_request_response)
        allow(service).to receive(:update_poa_request).with(anything).and_return('a successful response')
        allow(Lockbox).to receive(:new).and_return(mock_lockbox)
      end

      context 'when the feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return(true)
        end

        it 'enqueues the VANotifyDeclinedJob' do
          mock_ccg(scopes) do |auth_header|
            expect do
              decide_request_with(proc_id: '76529', decision: 'DECLINED', auth_header:, ptcpnt_id: '123456789',
                                  representative_id: '456')
            end.to change(ClaimsApi::VANotifyDeclinedJob.jobs, :size).by(1)
          end
        end
      end

      context 'when the feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return(false)
        end

        it 'does not enqueue the VANotifyDeclinedJob' do
          mock_ccg(scopes) do |auth_header|
            expect do
              decide_request_with(proc_id: '76529', decision: 'DECLINED', auth_header:, ptcpnt_id: '123456789',
                                  representative_id: '456')
            end.not_to change(ClaimsApi::VANotifyDeclinedJob.jobs, :size)
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
          serviceNumber: '123678453',
          serviceBranch: 'ARMY',
          address: {
            addressLine1: '2719 Hyperion Ave',
            addressLine2: 'Apt 2',
            city: 'Los Angeles',
            country: 'USA',
            stateCode: 'CA',
            zipCode: '92264',
            zipCodeSuffix: '0200'
          },
          phone: {
            areaCode: '555',
            phoneNumber: '5551234'
          },
          email: 'test@test.com',
          insuranceNumber: '1234567890'
        },
        poa: {
          poaCode: '003',
          registrationNumber: '12345',
          jobTitle: 'MyJob'
        },
        recordConsent: true,
        consentAddressChange: true,
        consentLimits: %w[
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

    it 'returns a created status, Lighthouse ID, and type in the response' do
      mock_ccg(scopes) do |auth_header|
        create_request_with(veteran_id:, form_attributes:, auth_header:)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['data']['attributes']['id']).not_to be_nil
        expect(JSON.parse(response.body)['data']['attributes']['type']).to eq('power-of-attorney-request')
      end
    end
  end

  def index_request_with(poa_codes:, auth_header:, filter: {})
    post v2_veterans_power_of_attorney_requests_path,
         params: { data: { attributes: { poaCodes: poa_codes, filter: } } }.to_json,
         headers: auth_header
  end

  def decide_request_with(proc_id:, decision:, auth_header:, ptcpnt_id: nil, representative_id: nil)
    post v2_veterans_power_of_attorney_requests_decide_path,
         params: { data: { attributes: { procId: proc_id, decision:, participantId: ptcpnt_id,
                                         representativeId: representative_id } } }.to_json,
         headers: auth_header
  end

  def create_request_with(veteran_id:, form_attributes:, auth_header:)
    post "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney-request",
         params: { data: { attributes: form_attributes } }.to_json,
         headers: auth_header
  end
end
