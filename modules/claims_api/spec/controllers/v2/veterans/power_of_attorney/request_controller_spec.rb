# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'

Rspec.describe ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController, type: :request do
  include ClaimsApi::Engine.routes.url_helpers

  describe '#index' do
    let(:scopes) { %w[claim.read] }
    let(:page_params) { { page: { size: '10', number: '2' } } }

    context 'when poaCodes is not present' do
      before do
        allow(subject).to receive(:params).and_return(page_params)
      end

      it 'raises a ParameterMissing error' do
        expect do
          subject.index
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when poaCodes is present but empty' do
      before do
        allow(subject).to receive_messages(form_attributes: { 'poaCodes' => [] }, params: page_params)
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
            expect(JSON.parse(response.body)['data'].size).to eq(3)
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

    context 'page params' do
      let(:poa_codes) { %w[002 003 083] }

      context 'page number is present' do
        context 'and page size is present' do
          context 'and exceeds the max value allowed' do
            it 'raises a 422' do
              page_params[:page][:size] = '101'
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_valid') do
                  index_request_with(poa_codes:, page_params:, auth_header:)

                  expect(response).to have_http_status(:bad_request)
                  expect(response.parsed_body['errors'][0]['detail']).to eq(
                    'The maximum page size param value of 100 has been exceeded.'
                  )
                end
              end
            end
          end

          context 'and exceeds the max value allowed along with page number' do
            it 'raises a 422' do
              page_params[:page][:size] = '101'
              page_params[:page][:number] = '120'
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_valid') do
                  index_request_with(poa_codes:, page_params:, auth_header:)

                  expect(response).to have_http_status(:bad_request)
                  expect(response.parsed_body['errors'][0]['detail']).to eq(
                    'Both the maximum page size param value of 100 has been exceeded ' \
                    'and the maximum page number param value of 100 has been exceeded.'
                  )
                end
              end
            end
          end
        end
      end

      context 'page size is present' do
        context 'and page number is not present' do
          it 'returns a success' do
            page_params[:page][:number] = nil
            mock_ccg(scopes) do |auth_header|
              VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_valid') do
                index_request_with(poa_codes:, page_params:, auth_header:)

                expect(response).to have_http_status(:ok)
              end
            end
          end
        end
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

  describe '#show' do
    let(:scopes) { %w[claim.read] }

    it 'returns a not found status if the PowerOfAttorneyRequest is not found' do
      mock_ccg(scopes) do |auth_header|
        show_request_with(id: 'some-missing-id', auth_header:)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the PowerOfAttorneyRequest is found' do
      let(:poa_request) { create(:claims_api_power_of_attorney_request) }
      let(:service) { instance_double(ClaimsApi::PowerOfAttorneyRequestService::Show) }

      before do
        allow(ClaimsApi::PowerOfAttorneyRequestService::Show).to receive(:new).and_return(service)
        allow(service).to receive(:get_poa_request).and_return({})
      end

      it 'returns a successful response' do
        mock_ccg(scopes) do |auth_header|
          show_request_with(id: poa_request.id, auth_header:)

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe '#decide' do
    let(:scopes) { %w[claim.write] }
    let(:id) { '348fa995-5b29-4819-91af-13f1bb3c7d77' }
    let(:request_response) do
      ClaimsApi::PowerOfAttorneyRequest.new(
        id: '348fa995-5b29-4819-91af-13f1bb3c7d77',
        proc_id: '76529',
        veteran_icn: '1008714701V416111',
        claimant_icn: '',
        poa_code: '123',
        metadata: {},
        power_of_attorney_id: nil
      )
    end

    context 'when the decide endpoint is called' do
      context 'when decision is not present' do
        let(:decision) { '' }

        before do
          allow(ClaimsApi::PowerOfAttorneyRequest).to receive(:find_by).and_return(request_response)
        end

        it 'raises an error if decision is not present' do
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
              decide_request_with(id:, decision:, auth_header:)
              expect(response).to have_http_status(:bad_request)
              response_body = JSON.parse(response.body)
              expect(response_body['errors'][0]['title']).to eq('Missing parameter')
              expect(response_body['errors'][0]['status']).to eq('400')
            end
          end
        end
      end

      context 'when decision is not ACCEPTED or DECLINED' do
        let(:decision) { 'indecision' }

        before do
          allow(ClaimsApi::PowerOfAttorneyRequest).to receive(:find_by).and_return(request_response)
        end

        it 'raises an error if decision is not valid' do
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
              decide_request_with(id:, decision:, auth_header:)
              expect(response).to have_http_status(:bad_request)
              response_body = JSON.parse(response.body)
              expect(response_body['errors'][0]['title']).to eq('Missing parameter')
              expect(response_body['errors'][0]['status']).to eq('400')
            end
          end
        end
      end
    end

    context 'when procId is present and valid and decision is accepted' do
      let(:decision) { 'ACCEPTED' }
      let(:service) { instance_double(ClaimsApi::PowerOfAttorneyRequestService::Show) }

      before do
        allow(ClaimsApi::PowerOfAttorneyRequest).to(receive(:find_by).and_return(request_response))
        allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController)
          .to receive(:fetch_ptcpnt_id).with(anything).and_return('5196105942')
        allow(ClaimsApi::PowerOfAttorneyRequestService::Show).to receive(:new).and_return(service)
        allow(service).to receive(:get_poa_request).and_return({})
      end

      it 'updates the secondaryStatus and returns a hash containing the ACC code' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
            decide_request_with(id:, decision:, auth_header:)
            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['data']['id']).to eq(id)
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
      let(:decision) { 'DECLINED' }
      let(:representative_id) { '456' }

      before do
        allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(anything).and_return(service)
        allow(service).to receive(:read_poa_request_by_ptcpnt_id).with(anything)
                                                                 .and_return(poa_request_response)
        allow(service).to receive(:update_poa_request).with(anything).and_return('a successful response')
        allow(ClaimsApi::PowerOfAttorneyRequest).to receive(:find_by).and_return(request_response)
        allow(Lockbox).to receive(:new).and_return(mock_lockbox)
      end

      context 'when the feature flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return(true)
        end

        it 'enqueues the VANotifyDeclinedJob' do
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('mpi/find_candidate/valid') do
              expect do
                decide_request_with(id:, decision:, auth_header:,
                                    representative_id:)
              end.to change(ClaimsApi::VANotifyDeclinedJob.jobs, :size).by(1)
            end
          end
        end
      end

      context 'when the feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return(false)
        end

        it 'does not enqueue the VANotifyDeclinedJob' do
          VCR.use_cassette('mpi/find_candidate/valid') do
            mock_ccg(scopes) do |auth_header|
              expect do
                decide_request_with(id:, decision:, auth_header:,
                                    representative_id:)
              end.not_to change(ClaimsApi::VANotifyDeclinedJob.jobs, :size)
            end
          end
        end
      end
    end

    context 'when id is present but invalid' do
      let(:id) { '1' }
      let(:decision) { 'ACCEPTED' }
      let(:representative_id) { '456' }

      it 'raises an error' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_not_found') do
            decide_request_with(id:, decision:, auth_header:, representative_id:)
            expect(response).to have_http_status(:not_found)
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
            countryCode: 'US',
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
        representative: {
          poaCode: '003'
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
    let(:claimant_information) do
      {
        claimant: {
          address: {
            addressLine1: '2719 Hyperion Ave',
            addressLine2: 'Apt 2',
            city: 'Los Angeles',
            countryCode: 'US',
            stateCode: 'CA',
            zipCode: '92264',
            zipCodeSuffix: '0200'
          },
          claimantId: '1012667145V762142',
          relationship: 'Spouse'
        }
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
        .with(anything)
        .and_return(nil)
      allow_any_instance_of(described_class).to receive(:validate_accredited_organization)
        .with(anything)
        .and_return(nil)
      allow_any_instance_of(described_class).to receive(:representative_data).and_return(representative_data)
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return(false)
      allow(ClaimsApi::PowerOfAttorneyRequestService::TerminateExistingRequests).to receive(:new)
        .with(anything)
        .and_return(terminate_existing_requests)
      allow(terminate_existing_requests).to receive(:call).and_return(nil)
      allow(ClaimsApi::PowerOfAttorneyRequestService::CreateRequest).to receive(:new)
        .with(anything, anything, anything)
        .and_return(create_request)
      allow(create_request).to receive(:call).and_return(create_request_response)
    end

    it 'returns a created status, Lighthouse ID, and type in the response' do
      mock_ccg(scopes) do |auth_header|
        create_request_with(veteran_id:, form_attributes:, auth_header:)
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['data']['id']).not_to be_nil
        expect(JSON.parse(response.body)['data']['type']).to eq('power-of-attorney-request')
      end
    end

    context 'handling countryCodes' do
      it 'returns a 422 when the veteran countryCode has no match in the BRD countries list' do
        mock_ccg(scopes) do |auth_header|
          form_attributes[:veteran][:address][:countryCode] = '76'
          create_request_with(veteran_id:, form_attributes:, auth_header:)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'The country provided is not valid.'
          )
        end
      end

      it 'returns a 201 when the veteran countryCode is lowercase but has a match' do
        mock_ccg(scopes) do |auth_header|
          form_attributes[:veteran][:address][:countryCode] = 'pk'
          create_request_with(veteran_id:, form_attributes:, auth_header:)

          expect(response).to have_http_status(:created)
        end
      end

      it 'returns a 422 when the claimant countryCode has no match in the BRD countries list' do
        mock_ccg(scopes) do |auth_header|
          form_attributes.merge!(claimant_information)
          form_attributes[:claimant][:address][:countryCode] = '76'
          create_request_with(veteran_id:, form_attributes:, auth_header:)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
            'The country provided is not valid.'
          )
        end
      end

      describe '#validate_country_code' do
        let(:min_form_attributes) do
          {
            'veteran' => {
              'address' => {
                'countryCode' => 'GB-WLS'
              }
            }
          }
        end

        before do
          allow(subject).to receive(:form_attributes).and_return(min_form_attributes)
        end

        it 'allows a countryCode with 6 characters and a dash' do
          response = subject.send(:validate_country_code)
          expect(response).to be_nil
        end

        it 'allows a countryCode with numbers and letters and a dash' do
          min_form_attributes['veteran']['address']['countryCode'] = 'TR-01'

          response = subject.send(:validate_country_code)
          expect(response).to be_nil
        end

        it 'allows a countryCode when sent in lowercase' do
          min_form_attributes['veteran']['address']['countryCode'] = 'gb'

          response = subject.send(:validate_country_code)
          expect(response).to be_nil
        end

        it 'allows a countryCode when sent in mixed case' do
          min_form_attributes['veteran']['address']['countryCode'] = 'gb-WlS'

          response = subject.send(:validate_country_code)
          expect(response).to be_nil
        end

        it 'denies an invalid countryCode' do
          min_form_attributes['veteran']['address']['countryCode'] = '%&-T)'

          expect do
            subject.send(:validate_country_code)
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
        end
      end

      describe '#validate_page_size_and_number_params' do
        context 'when no page params are sent in' do
          it 'assigns the default values when no page params are sent' do
            page_params = {}
            allow(subject).to receive(:params).and_return(page_params)

            subject.send(:validate_page_size_and_number_params)
            size = subject.instance_variable_get(:@page_size_param)
            number = subject.instance_variable_get(:@page_number_param)

            expect(size).to eq(10)
            expect(number).to eq(1)
          end

          it 'assigns the default values for when empty page params are sent' do
            page_params = { page: {} }
            allow(subject).to receive(:params).and_return(page_params)

            subject.send(:validate_page_size_and_number_params)
            size = subject.instance_variable_get(:@page_size_param)
            number = subject.instance_variable_get(:@page_number_param)

            expect(size).to eq(10)
            expect(number).to eq(1)
          end
        end

        context 'when params are invalid' do
          it 'returns a 422 when a alpha string is sent in' do
            param_val = 'abcdefg'
            page_params = { page: { size: param_val } }
            allow(subject).to receive(:params).and_return(page_params)

            expect do
              subject.send(:validate_page_size_and_number_params)
            end.to(raise_error do |error|
              expect(error.message).to eq('Bad request')
              expect(error.errors[0].detail).to eq("The page[size] param value #{param_val} is invalid")
            end)
          end

          it 'returns a 422 when a mixed string is sent in' do
            param_val = '12bbb'
            page_params = { page: { number: param_val } }
            allow(subject).to receive(:params).and_return(page_params)

            expect do
              subject.send(:validate_page_size_and_number_params)
            end.to(raise_error do |error|
              expect(error.message).to eq('Bad request')
              expect(error.errors[0].detail).to eq("The page[number] param value #{param_val} is invalid")
            end)
          end
        end

        context 'when only one param is sent' do
          context 'sets the param value and uses the default for the other' do
            it 'sets default page number when page size is sent in' do
              page_params = { page: { size: '5' } }
              allow(subject).to receive(:params).and_return(page_params)

              subject.send(:validate_page_size_and_number_params)
              size = subject.instance_variable_get(:@page_size_param)
              number = subject.instance_variable_get(:@page_number_param)

              expect(size).to eq(5)
              expect(number).to eq(1)
            end

            it 'sets default page size when page number is sent in' do
              page_params = { page: { number: '2' } }
              allow(subject).to receive(:params).and_return(page_params)

              subject.send(:validate_page_size_and_number_params)
              size = subject.instance_variable_get(:@page_size_param)
              number = subject.instance_variable_get(:@page_number_param)

              expect(size).to eq(10)
              expect(number).to eq(2)
            end
          end
        end
      end
    end
  end

  def index_request_with(poa_codes:, auth_header:, filter: {}, page_params: nil)
    post v2_veterans_power_of_attorney_requests_path,
         params: { page: { size: page_params&.dig(:page, :size),
                           number: page_params&.dig(:page, :number) },
                   data: { attributes: { poaCodes: poa_codes, filter: } } }.to_json,
         headers: auth_header.merge('Content-Type' => 'application/json')
  end

  def show_request_with(id:, auth_header:)
    get "/services/claims/v2/veterans/power-of-attorney-requests/#{id}", headers: auth_header
  end

  def decide_request_with(id:, decision:, auth_header:, representative_id: nil)
    post "/services/claims/v2/veterans/power-of-attorney-requests/#{id}/decide",
         params: { data: { attributes: { id:,
                                         decision:,
                                         representativeId: representative_id } } }.to_json,
         headers: auth_header.merge('Content-Type' => 'application/json')
  end

  def create_request_with(veteran_id:, form_attributes:, auth_header:)
    post "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney-request",
         params: { data: { attributes: form_attributes } }.to_json,
         headers: auth_header.merge('Content-Type' => 'application/json')
  end
end
