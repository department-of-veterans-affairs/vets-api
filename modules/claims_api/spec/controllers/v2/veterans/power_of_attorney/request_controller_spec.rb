# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'

Rspec.describe ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController, type: :request do
  include ClaimsApi::Engine.routes.url_helpers

  let(:address_expected) do
    { 'city' => 'Bourges', 'stateCode' => nil, 'zipCode' => '00123', 'countryCode' => 'France' }
  end

  let(:veteran_expected) do
    { 'firstName' => '[Vet First Name]', 'middleName' => nil, 'lastName' => '[Vet Last Name]' }
  end

  let(:claimant_expected) do
    { 'firstName' => '[Claimant First Name]', 'lastName' => '[Claimant Last Name]' }
  end
  let(:dependent) do
    OpenStruct.new(
      first_name: 'Wally',
      last_name: 'Morell',
      middle_name: nil
    )
  end

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
            parsed_response = JSON.parse(response.body)['data']
            veteran = parsed_response[0]['attributes']['veteran']
            claimant = parsed_response[0]['attributes']['claimant']
            address = parsed_response[2]['attributes']['address']
            expect(veteran).to eq(veteran_expected)
            expect(claimant).to eq(claimant_expected)
            expect(address).to eq(address_expected)
            expect(parsed_response.size).to eq(3)
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

    context 'when the request is filed by a dependent' do
      let(:dependent_icn) { '1013093331V548481' }
      let(:poa_list_only_dependent_info) do
        [
          {
            'claimant_icn' => nil
          }, {
            'claimant_icn' => dependent_icn
          }
        ]
      end

      it 'add the frst_name and last_name of the claimant to the appropriate records' do
        allow(subject).to receive(:build_veteran_or_dependent_data).with(anything).and_return(dependent)

        poa_list_with_dependent = subject.send(:add_dependent_data_to_poa_response, poa_list_only_dependent_info)
        dependent_record = poa_list_with_dependent.find { |item| item['claimant_icn'] == dependent_icn }

        expect(dependent_record['claimantFirstName']).to eq(dependent.first_name)
        expect(dependent_record['claimantLastName']).to eq(dependent.last_name)
      end
    end
  end

  describe '#show' do
    let(:scopes) { %w[claim.read] }
    let(:mock_get_poa) do
      { 'VSOUserEmail' => nil,
        'VSOUserFirstName' => 'Joe',
        'VSOUserLastName' => 'BestRep',
        'changeAddressAuth' => 'Y',
        'claimantCity' => 'Charlottesville',
        'claimantCountry' => 'USA',
        'claimantMilitaryPO' => nil,
        'claimantMilitaryPostalCode' => nil,
        'claimantState' => nil,
        'claimantZip' => '00123',
        'dateRequestActioned' => '2024-05-25T13:45:00-05:00',
        'dateRequestReceived' => '2012-11-23T16:49:16-06:00',
        'declinedReason' => nil,
        'healthInfoAuth' => 'Y',
        'poaCode' => '083',
        'procID' => '11027',
        'secondaryStatus' => 'New',
        'vetFirstName' => '[Vet First Name]',
        'vetLastName' => '[Vet Last Name]',
        'vetMiddleName' => nil,
        'vetPtcpntID' => '111',
        'claimantFirstName' => '[Claimant First Name]',
        'claimantLastName' => '[Claimant Last Name]',
        'id' => nil }
    end
    let(:address_expected) do
      { 'city' => 'Charlottesville', 'stateCode' => nil, 'zipCode' => '00123', 'countryCode' => 'USA' }
    end

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
        allow(service).to receive(:get_poa_request).and_return(mock_get_poa)
      end

      it 'returns a successful response' do
        mock_ccg(scopes) do |auth_header|
          show_request_with(id: poa_request.id, auth_header:)

          expect(response).to have_http_status(:ok)
          parsed_response = JSON.parse(response.body)['data']
          veteran = parsed_response['attributes']['veteran']
          claimant = parsed_response['attributes']['claimant']
          address = parsed_response['attributes']['address']
          expect(veteran).to eq(veteran_expected)
          expect(claimant).to eq(claimant_expected)
          expect(address).to eq(address_expected)
        end
      end
    end

    context 'when the request is filed by a dependent' do
      let(:service) { instance_double(ClaimsApi::PowerOfAttorneyRequestService::Show) }
      let(:dependent_icn) { '1013093331V548481' }
      let(:poa_res_only_dependent_info) do
        {
          'VSOUserEmail' => nil, 'VSOUserFirstName' => 'VDC USER', 'VSOUserLastName' => nil,
          'changeAddressAuth' => 'Y', 'claimantCity' => 'Los Angeles', 'claimantCountry' => 'Vietnam',
          'claimantMilitaryPO' => nil, 'claimantMilitaryPostalCode' => nil, 'claimantState' => 'CA',
          'claimantZip' => '92264', 'dateRequestActioned' => '2025-08-13T15:21:51-05:00',
          'dateRequestReceived' => '2025-08-13T15:21:51-05:00', 'declinedReason' => nil, 'healthInfoAuth' => 'Y',
          'poaCode' => '067', 'procID' => '3865154', 'secondaryStatus' => 'New', 'vetFirstName' => 'Margie',
          'vetLastName' => 'Curtis', 'vetMiddleName' => nil, 'vetPtcpntID' => '600052700'
        }
      end
      let(:poa_request_with_dependent) { create(:claims_api_power_of_attorney_request, claimant_icn: dependent_icn) }

      before do
        allow(ClaimsApi::PowerOfAttorneyRequestService::Show).to receive(:new).and_return(service)
        allow(service).to receive(:get_poa_request).and_return(poa_res_only_dependent_info)
      end

      it 'has the claimant firstName and lastName in the response' do
        mock_ccg(scopes) do |auth_header|
          show_request_with(id: poa_request_with_dependent.id, auth_header:)

          expect(JSON.parse(response.body)['data']['attributes']['claimant']['firstName']).not_to be_nil
          expect(JSON.parse(response.body)['data']['attributes']['claimant']['lastName']).not_to be_nil
        end
      end
    end
  end

  describe '#decide' do
    let(:scopes) { %w[claim.write] }
    let(:lighthouse_id) { '348fa995-5b29-4819-91af-13f1bb3c7d77' }
    let(:vet_icn) { '1012667169V030190' }
    let(:dependent_icn) { '1013093331V548481' }
    let(:request_response) do
      ClaimsApi::PowerOfAttorneyRequest.new(
        id: lighthouse_id,
        proc_id: '76529',
        veteran_icn: vet_icn,
        claimant_icn: '',
        poa_code: '123',
        metadata: {},
        power_of_attorney_id: nil
      )
    end
    let(:request_response_with_dependent) do
      ClaimsApi::PowerOfAttorneyRequest.new(
        id: lighthouse_id,
        proc_id: '76529',
        veteran_icn: vet_icn,
        claimant_icn: dependent_icn,
        poa_code: '123',
        metadata: {},
        power_of_attorney_id: nil
      )
    end
    let(:accepted_form_attributes) do
      {
        decision: 'ACCEPTED',
        declinedReason: nil,
        representativeId: '987654321654'
      }
    end
    let(:declined_form_attributes) do
      {
        decision: 'DECLINED',
        declinedReason: 'Reason for declining',
        representativeId: '123456789456'
      }
    end
    let(:veteran) do
      OpenStruct.new(
        icn: vet_icn,
        first_name: 'Ralph',
        last_name: 'Lee',
        middle_name: nil,
        birls_id: '796378782',
        birth_date: '1948-10-30',
        loa: { current: 3, highest: 3 },
        edipi: nil,
        ssn: '796378782',
        participant_id: '600043284',
        mpi: OpenStruct.new(
          icn: vet_icn,
          profile: OpenStruct.new(ssn: '796378782')
        )
      )
    end

    context 'when the decide endpoint is called' do
      context 'when decision is not present' do
        before do
          allow(ClaimsApi::PowerOfAttorneyRequest).to receive(:find_by).and_return(request_response)
        end

        it 'raises an error if decision is not present' do
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
              accepted_form_attributes[:decision] = ''
              decide_request_with(id: lighthouse_id, form_attributes: accepted_form_attributes, auth_header:)

              response_body = JSON.parse(response.body)

              expect(response).to have_http_status(:unprocessable_entity)
              expect(response_body['errors'][0]['detail']).to include(
                'The property /decision did not match the following requirements:'
              )
            end
          end
        end
      end

      context 'when decision is not ACCEPTED or DECLINED' do
        before do
          allow(ClaimsApi::PowerOfAttorneyRequest).to receive(:find_by).and_return(request_response)
        end

        it 'raises an error if decision is not valid' do
          mock_ccg(scopes) do |auth_header|
            declined_form_attributes[:decision] = 'indecision'
            decide_request_with(id: lighthouse_id, form_attributes: declined_form_attributes, auth_header:)

            response_body = JSON.parse(response.body)

            expect(response).to have_http_status(:unprocessable_entity)
            expect(response_body['errors'][0]['detail']).to include(
              'The property /decision did not match the following requirements:'
            )
          end
        end
      end
    end

    context 'when procId is present and valid and decision is accepted' do
      before do
        allow(ClaimsApi::PowerOfAttorneyRequest).to(receive(:find_by).and_return(request_response))
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:get_poa_request).and_return({ 'id' => lighthouse_id })
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:validate_decide_representative_params!).with(anything, anything).and_return(nil)
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:build_veteran_and_dependent_data).with(anything, anything).and_return(veteran)
        allow_any_instance_of(ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController)
          .to receive(:process_poa_decision).and_return(OpenStruct.new(id: request_response.id))
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return(false)
      end

      it 'updates the secondaryStatus and returns a hash containing the ACC code' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
            decide_request_with(id: lighthouse_id, form_attributes: accepted_form_attributes, auth_header:)

            response_body = JSON.parse(response.body)

            expect(response).to have_http_status(:ok)
            expect(response_body['data']['id']).to eq(lighthouse_id)
          end
        end
      end

      it 'includes location in the response header' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
            decide_request_with(id: lighthouse_id, form_attributes: accepted_form_attributes, auth_header:)

            expect(response.headers).to have_key('Location')
          end
        end
      end
    end

    context 'handling the ACCEPTED decision' do
      let(:ptcpnt_id) { '600043284' }
      let(:representative_id) { '8942584724354' }
      let(:params) do
        {
          decision: 'ACCEPTED', proc_id: '09876', representative_id:, poa_code:,
          metadata: {}, veteran:, claimant: nil
        }
      end
      let(:poa_code) { '067' }
      let(:form_type_code) { '2122a' }
      let(:return_data) do
        [{ 'data' => { 'attributes' => { 'some_key' => 'some_value' } } }, form_type_code]
      end
      let(:veteran) do
        OpenStruct.new(
          participant_id: ptcpnt_id
        )
      end
      let(:form_attributes) do
        { 'some_key' => 'some_value' }
      end
      let(:dummy_record) do
        OpenStruct.new(id: '8675309')
      end

      before do
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::DecisionHandler
        ).to receive(:call).and_return(return_data)
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:validate_decide_representative_params!).with(anything, anything).and_return(nil)
        allow_any_instance_of(
          ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController
        ).to receive(:build_auth_headers).and_return({})
        allow(ClaimsApi::PowerOfAttorney).to receive(:create!).with(anything).and_return(dummy_record)
        allow_any_instance_of(
          ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController
        ).to receive(:claims_v2_logging)
      end

      it 'returns nil from the decision handler' do
        expect_any_instance_of(
          ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController
        ).to receive(:validate_mapped_data!).with(ptcpnt_id, form_type_code, poa_code)
        expect_any_instance_of(
          ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController
        ).to receive(:decide_request_attributes).with(
          poa_code:, decide_form_attributes: form_attributes
        ).and_return(return_data[0]['data']['attributes'])
        expect_any_instance_of(
          ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController
        ).to receive(:claims_v2_logging).with(
          'process_poa_decision', { message: 'Record saved, sending to POA Form Builder Job' }
        )

        returned_poa = subject.send(:process_poa_decision, **params)

        expect(returned_poa.id).to eq(dummy_record.id)
      end
    end

    context 'when the request has dependent information included' do
      let(:service) { instance_double(ClaimsApi::PowerOfAttorneyRequestService::Decide) }
      let(:veteran_info) do
        OpenStruct.new(
          icn: '1013030865V203693',
          first_name: 'Margie',
          last_name: 'Curtis',
          middle_name: nil,
          birls_id: '234251634',
          birth_date: '1948-10-30',
          loa: { current: 3, highest: 3 },
          edipi: nil,
          ssn: '234251634',
          participant_id: '600052700',
          mpi: OpenStruct.new(
            icn: vet_icn,
            profile: OpenStruct.new(ssn: '234251634')
          )
        )
      end
      let(:claimant_info) do
        OpenStruct.new(
          icn: '1013030865V203693',
          first_name: 'Jerry',
          last_name: 'Curtis',
          middle_name: nil,
          birls_id: '796378782',
          birth_date: '1948-10-30',
          loa: { current: 3, highest: 3 },
          edipi: nil,
          ssn: '796378782',
          participant_id: '600052699',
          mpi: OpenStruct.new(
            icn: vet_icn,
            profile: OpenStruct.new(ssn: '796378782')
          )
        )
      end
      let(:poa_res_only_dependent_info) do
        {
          'VSOUserEmail' => nil, 'VSOUserFirstName' => 'VDC USER', 'VSOUserLastName' => nil,
          'changeAddressAuth' => 'Y', 'claimantCity' => 'Los Angeles', 'claimantCountry' => 'Vietnam',
          'claimantMilitaryPO' => nil, 'claimantMilitaryPostalCode' => nil, 'claimantState' => 'CA',
          'claimantZip' => '92264', 'dateRequestActioned' => '2025-08-13T15:21:51-05:00',
          'dateRequestReceived' => '2025-08-13T15:21:51-05:00', 'declinedReason' => nil, 'healthInfoAuth' => 'Y',
          'poaCode' => '067', 'procID' => '3865154', 'secondaryStatus' => 'New', 'vetFirstName' => 'Margie',
          'vetLastName' => 'Curtis', 'vetMiddleName' => nil, 'vetPtcpntID' => '600052700'
        }
      end
      let(:poa_request_with_dependent) do
        create(
          :claims_api_power_of_attorney_request, veteran_icn: veteran_info.icn, claimant_icn: claimant_info.icn
        )
      end

      before do
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:validate_decide_representative_params!).with(anything, anything).and_return(nil)
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:build_veteran_and_dependent_data).with(anything,
                                                             anything).and_return([veteran_info, claimant_info])
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:get_poa_request).and_return(poa_res_only_dependent_info)
      end

      it 'has the claimant firstName and lastName in the response' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_valid') do
            decide_request_with(id: poa_request_with_dependent.id, form_attributes: declined_form_attributes,
                                auth_header:)

            claimant_object = JSON.parse(response.body)['data']['attributes']['claimant']

            expect(claimant_object['firstName']).to eq(claimant_info.first_name)
            expect(claimant_object['lastName']).to eq(claimant_info.last_name)
          end
        end
      end
    end

    context 'when the decision is declined and a ptcpntId is present' do
      let(:decision) { 'DECLINED' }
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
        allow(service).to receive(:read_poa_request_by_ptcpnt_id).with(anything)
                                                                 .and_return(poa_request_response)
        allow(service).to receive(:update_poa_request).with(anything).and_return('a successful response')
        allow(ClaimsApi::PowerOfAttorneyRequest).to receive(:find_by).and_return(request_response)
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::Decide
        ).to receive(:validate_decide_representative_params!).with(anything, anything).and_return(nil)
        allow(Lockbox).to receive(:new).and_return(mock_lockbox)
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return(false)
      end

      it 'calls the decision handler' do
        mock_ccg(scopes) do |auth_header|
          expect(ClaimsApi::PowerOfAttorneyRequestService::DecisionHandler).to receive(:new)

          decide_request_with(id: lighthouse_id, form_attributes: declined_form_attributes, auth_header:)
        end
      end

      it 'does not include location in the response header' do
        mock_ccg(scopes) do |auth_header|
          decide_request_with(id: lighthouse_id, form_attributes: declined_form_attributes, auth_header:)

          expect(response.headers).not_to have_key('Location')
        end
      end

      context 'handling the decision' do
        before do
          allow_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::DecisionHandler).to receive(:call)
                                                                                          .and_return(nil)
        end

        let(:params) do
          {
            decision:, proc_id: '09876', representative_id: '8942584724354', poa_code: '083',
            metadata: {}, veteran: nil, claimant: nil
          }
        end

        it 'returns nil from the decision handler' do
          res = subject.send(:process_poa_decision, **params)

          expect(res).to be_nil
        end
      end
    end

    context 'validating the params' do
      context 'when id is present but invalid' do
        let(:id) { '1' }

        it 'raises an error' do
          mock_ccg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_not_found') do
              decide_request_with(id:, form_attributes: accepted_form_attributes, auth_header:)

              expect(response).to have_http_status(:not_found)
              expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
                "Could not find Power of Attorney request with id: #{id}"
              )
            end
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

    context 'returning a Lighthouse ID' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_v2_poa_requests_skip_bgs).and_return(true)
      end

      let(:sandbox_lh_id) { 'c5ab49ca-0bd3-4529-8c48-5e277083f9eb' }

      it 'returns a specific ID when the flipper is enabled' do
        mock_ccg(scopes) do |auth_header|
          create_request_with(veteran_id:, form_attributes:, auth_header:)

          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)['data']['id']).to eq(sandbox_lh_id)
        end
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

      describe 'handling international phone numbers' do
        it 'returns the countryCode for the phone number in the response when an international number is used' do
          mock_ccg(scopes) do |auth_header|
            form_attributes[:veteran][:phone][:countryCode] = '91'
            form_attributes[:veteran][:phone][:areaCode] = '22'
            form_attributes[:veteran][:phone][:phoneNumber] = '12345678'
            create_request_with(veteran_id:, form_attributes:, auth_header:)

            parsed_response = JSON.parse(response.body)['data']
            phone = parsed_response['attributes']['veteran']['phone']

            expect(response).to have_http_status(:created)
            expect(phone['countryCode']).to eq('91')
            expect(phone['areaCode']).to eq('22')
            expect(phone['phoneNumber']).to eq('12345678')
          end
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

  def decide_request_with(id:, form_attributes:, auth_header:)
    post "/services/claims/v2/veterans/power-of-attorney-requests/#{id}/decide",
         params: { data: { attributes: form_attributes } }.to_json,
         headers: auth_header.merge('Content-Type' => 'application/json')
  end

  def create_request_with(veteran_id:, form_attributes:, auth_header:)
    post "/services/claims/v2/veterans/#{veteran_id}/power-of-attorney-request",
         params: { data: { attributes: form_attributes } }.to_json,
         headers: auth_header.merge('Content-Type' => 'application/json')
  end
end
