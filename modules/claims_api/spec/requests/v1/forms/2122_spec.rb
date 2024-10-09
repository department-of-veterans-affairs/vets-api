# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'bgs_service/local_bgs'

RSpec.describe 'ClaimsApi::V1::Forms::2122', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.read claim.write] }
  let(:multi_profile) do
    MPI::Responses::FindProfileResponse.new(
      status: :ok,
      profile: FactoryBot.build(:mpi_profile, participant_id: nil, participant_ids: %w[123456789 987654321])
    )
  end
  let(:pws) { ClaimsApi::LocalBGS }

  before do
    stub_poa_verification
  end

  describe '#2122' do
    let(:data) { Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json').read }
    let(:data_with_claimant) do
      parsed_data = JSON.parse(data)
      parsed_data['data']['attributes']['claimant'] = { firstName: 'Jane', lastName: 'Doe' }
      parsed_data.to_json
    end
    let(:path) { '/services/claims/v1/forms/2122' }
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '2122.json').read }

    describe 'schema' do
      it 'returns a successful get response with json schema' do
        get path
        json_schema = JSON.parse(response.body)['data'][0]
        expect(json_schema).to eq(JSON.parse(schema))
      end
    end

    describe '#submit_form_2122' do
      let(:bgs_poa_verifier) { BGS::PowerOfAttorneyVerifier.new(nil) }

      context 'when poa code is valid' do
        before do
          Veteran::Service::Representative.new(representative_id: '01234', poa_codes: ['074']).save!
        end

        context 'when poa code is associated with current user' do
          before do
            Veteran::Service::Representative.new(representative_id: '56789', poa_codes: ['074'],
                                                 first_name: 'Abraham', last_name: 'Lincoln').save!
          end

          context 'when Veteran has all necessary identifiers' do
            it 'assigns a source' do
              mock_acg(scopes) do |auth_header|
                allow_any_instance_of(pws)
                  .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
                allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                  .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
                allow(bgs_poa_verifier).to receive(:current_poa_code).and_return(Struct.new(:code).new('HelloWorld'))
                post path, params: data, headers: headers.merge(auth_header)
                token = JSON.parse(response.body)['data']['id']
                poa = ClaimsApi::PowerOfAttorney.find(token)
                expect(poa.source_data['name']).to eq('abraham lincoln')
                expect(poa.source_data['icn'].present?).to eq(true)
                expect(poa.source_data['email']).to eq('abraham.lincoln@vets.gov')
              end
            end

            it 'returns a successful response with all the data' do
              mock_acg(scopes) do |auth_header|
                allow_any_instance_of(pws)
                  .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
                allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                  .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
                allow(bgs_poa_verifier).to receive(:current_poa_code).and_return(Struct.new(:code).new('HelloWorld'))
                post path, params: data, headers: headers.merge(auth_header)
                parsed = JSON.parse(response.body)
                expect(parsed['data']['type']).to eq('claims_api_power_of_attorneys')
                expect(parsed['data']['attributes']['status']).to eq('pending')
              end
            end

            it "assigns a 'cid' (OKTA client_id)" do
              mock_acg(scopes) do |auth_header|
                allow_any_instance_of(pws)
                  .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
                allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                  .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
                allow(bgs_poa_verifier).to receive(:current_poa_code).and_return(Struct.new(:code).new('HelloWorld'))
                post path, params: data, headers: headers.merge(auth_header)
                token = JSON.parse(response.body)['data']['id']
                poa = ClaimsApi::PowerOfAttorney.find(token)
                expect(poa[:cid]).to eq('0oa41882gkjtBRJhu2p7')
              end
            end
          end

          context 'when Veteran is missing a participant_id' do
            before do
              stub_mpi_not_found
            end

            context 'when consumer is representative' do
              it 'returns an unprocessible entity status' do
                mock_acg(scopes) do |auth_header|
                  post path, params: data, headers: headers.merge(auth_header)
                  expect(response).to have_http_status(:unprocessable_entity)
                end
              end
            end

            context 'when consumer is Veteran and missing EDIPI' do
              it 'catches a raised 422' do
                mock_acg(scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
                    allow_any_instance_of(MPIData)
                      .to receive(:mvi_response).and_return(multi_profile)
                    post path, params: data, headers: auth_header

                    response_body = JSON.parse response.body
                    expect(response).to have_http_status(:unprocessable_entity)
                    expect(response_body['errors'][0]['detail']).to eq(
                      "Unable to locate Veteran's Participant ID in Master Person Index (MPI). " \
                      'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
                    )
                  end
                end
              end
            end
          end

          context 'when Veteran has participant_id' do
            context 'when Veteran is missing a birls_id' do
              context 'when birls_id isn`t required' do
                before do
                  stub_mpi(build(:mpi_profile, birls_id: nil))
                end

                it 'returns a 200' do
                  mock_acg(scopes) do |auth_header|
                    allow_any_instance_of(pws)
                      .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
                    allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                      .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                    allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
                    allow(bgs_poa_verifier).to receive(:current_poa_code)
                      .and_return(Struct.new(:code).new('HelloWorld'))
                    post path, params: data, headers: headers.merge(auth_header)
                    expect(response).to have_http_status(:ok)
                  end
                end
              end
            end
          end

          context 'when a request includes signatures' do
            it 'Generates a 21-22 or 21-22a form to submit to VBMS' do
              mock_acg(scopes) do |auth_header|
                allow_any_instance_of(pws)
                  .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
                allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                  .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
                allow(bgs_poa_verifier).to receive(:current_poa_code).and_return(Struct.new(:code).new('HelloWorld'))
                params = JSON.parse data
                base64_signature = File.read(Rails.root.join(
                  *'/modules/claims_api/spec/fixtures/signature_b64.txt'.split('/')
                ).to_s)
                signatures = { veteran: base64_signature, representative: base64_signature }
                params['data']['attributes']['signatures'] = signatures

                expect(ClaimsApi::V1::PoaFormBuilderJob).to receive(:perform_async)

                post path, params: params.to_json, headers: headers.merge(auth_header)
              end
            end
          end

          context 'when a request doesn\'t include signatures' do
            it 'Doesn\'t generate a 21-22 or 21-22a form to upload to VBMS' do
              mock_acg(scopes) do |auth_header|
                expect(ClaimsApi::V1::PoaFormBuilderJob).not_to receive(:perform_async)

                post path, params: data, headers: headers.merge(auth_header)
              end
            end
          end
        end

        context 'when the current user is the Veteran and uses request headers' do
          let(:headers) do
            { 'X-VA-SSN': '796111863',
              'X-VA-First-Name': 'Abraham',
              'X-VA-Last-Name': 'Lincoln',
              'X-VA-Birth-Date': '1809-02-12',
              'X-VA-Gender': 'M' }
          end

          it 'responds with a 422' do
            mock_acg(scopes) do |auth_header|
              allow(Veteran::Service::Representative).to receive(:all_for_user).and_return([])
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)

              post path, params: data, headers: headers.merge(auth_header)

              expect(response).to have_http_status(:unprocessable_entity)
              error_detail = JSON.parse(response.body)['errors'][0]['detail']
              substring = 'Veterans making requests do not need to include identifying headers'
              expect(error_detail.include?(substring)).to be true
            end
          end
        end

        context 'when poa code is not associated with current user' do
          it 'responds with invalid poa code message' do
            mock_acg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)
              post path, params: data, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:bad_request)
            end
          end
        end
      end

      context 'when poa code is not valid' do
        it 'responds with invalid poa code message' do
          mock_acg(scopes) do |auth_header|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            post path, params: data, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:bad_request)
          end
        end
      end

      context 'validate_veteran_identifiers' do
        context 'when Veteran identifiers are missing in MPI lookups' do
          before do
            stub_mpi(build(:mpi_profile, birth_date: nil, participant_id: nil))
          end

          it 'returns an unprocessible entity status' do
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_raise(ArgumentError)
            mock_acg(scopes) do |auth_header|
              post path, params: data, headers: headers.merge(auth_header)
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when the birth date in the headers is an empty string' do
          let(:invalid_headers) do
            { 'X-VA-SSN': '796111863',
              'X-VA-First-Name': 'Abraham',
              'X-VA-Last-Name': 'Lincoln',
              'X-VA-Birth-Date': '',
              'X-VA-Gender': 'M' }
          end

          it 'responds with invalid birth_date' do
            mock_acg(scopes) do |auth_header|
              allow(Veteran::Service::Representative).to receive(:all_for_user).and_return([])
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)

              post path, params: data, headers: invalid_headers.merge(auth_header)

              expect(response).to have_http_status(:unprocessable_entity)
              error_detail = JSON.parse(response.body)['errors'][0]['detail']
              substring = 'The following values are invalid: X-VA-Birth-Date'
              expect(error_detail).to eq(substring)
            end
          end
        end

        context 'when the first and last name in the headers is an empty string' do
          let(:invalid_headers) do
            { 'X-VA-SSN': '796111863',
              'X-VA-First-Name': '',
              'X-VA-Last-Name': '',
              'X-VA-Birth-Date': '1809-02-12',
              'X-VA-Gender': 'M' }
          end

          it 'responds with invalid birth_date' do
            mock_acg(scopes) do |auth_header|
              allow(Veteran::Service::Representative).to receive(:all_for_user).and_return([])
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)

              post path, params: data, headers: invalid_headers.merge(auth_header)

              expect(response).to have_http_status(:unprocessable_entity)
              error_detail = JSON.parse(response.body)['errors'][0]['detail']
              substring = 'The following values are invalid: X-VA-First-Name, X-VA-Last-Name'
              expect(error_detail).to eq(substring)
            end
          end
        end
      end

      context 'request schema validations' do
        let(:json_data) { JSON.parse data }

        it 'requires poa_code subfield' do
          mock_acg(scopes) do |auth_header|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            params = json_data
            params['data']['attributes']['serviceOrganization']['poaCode'] = nil
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'].size).to eq(1)
          end
        end

        it 'doesn\'t allow additional fields' do
          mock_acg(scopes) do |auth_header|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            params = json_data
            params['data']['attributes']['someBadField'] = 'someValue'
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'].size).to eq(1)
            expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
              'The property /someBadField is not defined on the schema. Additional properties are not allowed'
            )
          end
        end
      end

      context 'request schema validation of aptUnitNumber' do
        before do
          Veteran::Service::Representative.new(representative_id: '56789', poa_codes: ['074'],
                                               first_name: 'Abraham', last_name: 'Lincoln').save!
        end

        let(:path) { '/services/claims/v1/forms/2122/validate' }
        let(:vetdata) do
          {
            address: {
              numberAndStreet: '76 Crowther Ave',
              aptUnitNumber: '11C',
              city: 'Bridgeport',
              country: 'US',
              state: 'CT',
              zipFirstFive: '06616'
            }
          }
        end

        it 'allows alphanumeric strings for aptUnitNumber' do
          mock_acg(scopes) do |auth_header|
            allow_any_instance_of(pws)
              .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            params = JSON.parse data
            params['data']['attributes']['veteran'] = vetdata
            post path, params: params.to_json, headers: headers.merge(auth_header)
            expect(response).to have_http_status(:ok)
          end
        end
      end

      shared_context 'stub validation methods' do
        before do
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:check_request_ssn_matches_mpi).and_return(nil)
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:validate_json_schema).and_return(nil)
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:validate_poa_code!).and_return(nil)
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:validate_poa_code_for_current_user!).and_return(nil)
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:check_file_number_exists!).and_return(nil)
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:validate_dependent_claimant!).and_return(nil)
          allow_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
            .to receive(:assign_poa_to_dependent!).and_return(nil)
        end
      end

      context 'when the lighthouse_claims_api_poa_dependent_claimants feature is enabled' do
        include_context 'stub validation methods'

        before do
          Flipper.enable(:lighthouse_claims_api_poa_dependent_claimants)
        end

        context 'and the request includes a dependent claimant' do
          it 'calls assign_poa_to_dependent!' do
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
                .to receive(:assign_poa_to_dependent!)

              post path, params: data_with_claimant, headers: headers.merge(auth_header)
            end
          end
        end

        context 'and the request does not include a dependent claimant' do
          it 'does not call assign_poa_to_dependent!' do
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
                .not_to receive(:assign_poa_to_dependent!)

              post path, params: data, headers: headers.merge(auth_header)
            end
          end
        end
      end

      context 'when the lighthouse_claims_api_poa_dependent_claimants feature is disabled' do
        include_context 'stub validation methods'

        before do
          Flipper.disable(:lighthouse_claims_api_poa_dependent_claimants)
        end

        it 'does not call assign_poa_to_dependent!' do
          mock_acg(scopes) do |auth_header|
            expect_any_instance_of(ClaimsApi::DependentClaimantPoaAssignmentService)
              .not_to receive(:assign_poa_to_dependent!)

            post path, params: data_with_claimant, headers: headers.merge(auth_header)
          end
        end
      end
    end

    describe '#status' do
      let(:power_of_attorney) { create(:power_of_attorney, :submitted, auth_headers: headers) }

      it 'return the status of a POA based on GUID' do
        mock_acg(scopes) do |auth_header|
          get("#{path}/#{power_of_attorney.id}",
              params: nil, headers: headers.merge(auth_header))
          parsed = JSON.parse(response.body)
          expect(parsed['data']['type']).to eq('claims_api_power_of_attorneys')
          expect(parsed['data']['attributes']['status']).to eq('submitted')
        end
      end
    end

    describe '#upload' do
      let(:power_of_attorney) { create(:power_of_attorney) }
      let(:binary_params) do
        { attachment: Rack::Test::UploadedFile.new(Rails.root.join(
          *'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')
        ).to_s) }
      end
      let(:base64_params) do
        { attachment: File.read(Rails.root.join(*'/modules/claims_api/spec/fixtures/base64pdf'.split('/')).to_s) }
      end

      it 'submit binary and change the document status' do
        mock_acg(scopes) do |auth_header|
          allow_any_instance_of(pws)
            .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:check_request_ssn_matches_mpi).and_return(nil)
          allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
          expect(power_of_attorney.file_data).to be_nil
          put("#{path}/#{power_of_attorney.id}",
              params: binary_params, headers: headers.merge(auth_header))
          power_of_attorney.reload
          expect(power_of_attorney.file_data).not_to be_nil
          expect(power_of_attorney.status).to eq('submitted')
        end
      end

      it 'submit base64 and change the document status' do
        mock_acg(scopes) do |auth_header|
          allow_any_instance_of(pws)
            .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:check_request_ssn_matches_mpi).and_return(nil)
          allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
          expect(power_of_attorney.file_data).to be_nil
          put("#{path}/#{power_of_attorney.id}",
              params: base64_params, headers: headers.merge(auth_header))
          power_of_attorney.reload
          expect(power_of_attorney.file_data).not_to be_nil
          expect(power_of_attorney.status).to eq('submitted')
        end
      end

      context 'The controller checks the check_request_ssn_matches_mpi before calling BGS' do
        context 'and it catches an invalid ssn' do
          let(:poa) { create(:power_of_attorney, auth_headers: headers) }

          it 'returns a message to the consumer' do
            mock_acg(scopes) do |auth_header|
              allow_any_instance_of(pws)
                .to receive(:find_by_ssn).and_return({ file_nbr: '1234567' })
              put("#{path}/#{power_of_attorney.id}", params: binary_params, headers: headers.merge(auth_header))
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).with('987654321')
              parsed = JSON.parse(response.body)
              expect(response).to have_http_status(:unprocessable_entity)
              expect(parsed['errors'].first['title']).to eq('Unprocessable Entity')
            end
          end
        end
      end

      context "when checking if Veteran has a valid 'FileNumber'" do
        context 'when the call to BGS raises an error' do
          it 'returns a 424' do
            mock_acg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)
              allow_any_instance_of(pws)
                .to receive(:find_by_ssn).and_raise(BGS::ShareError.new('HelloWorld'))
              expect(power_of_attorney.file_data).to be_nil
              put("#{path}/#{power_of_attorney.id}",
                  params: base64_params, headers: headers.merge(auth_header))
              power_of_attorney.reload
              parsed = JSON.parse(response.body)
              expect(power_of_attorney.file_data).to be_nil
              expect(response).to have_http_status(:failed_dependency)
              expect(parsed['errors'].first['title']).to eq('Failed Dependency')
              expect(parsed['errors'].first['detail']).to eq('Failure occurred in a system dependency')
            end
          end
        end

        context 'BGS response is invalid' do
          let(:error_detail) do
            "Unable to locate Veteran's File Number in Master Person Index (MPI). " \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
          end

          context "when the BGS response is 'nil'" do
            it 'returns a 422' do
              mock_acg(scopes) do |auth_header|
                allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                  .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                allow_any_instance_of(pws)
                  .to receive(:find_by_ssn).and_return(nil)
                expect(power_of_attorney.file_data).to be_nil
                put("#{path}/#{power_of_attorney.id}",
                    params: base64_params, headers: headers.merge(auth_header))
                power_of_attorney.reload
                parsed = JSON.parse(response.body)
                expect(power_of_attorney.file_data).to be_nil
                expect(response).to have_http_status(:unprocessable_entity)
                expect(parsed['errors'].first['title']).to eq('Unprocessable Entity')
                expect(parsed['errors'].first['detail']).to eq(error_detail)
              end
            end
          end

          context "when 'file_nbr' in the BGS response is 'nil'" do
            it 'returns a 422' do
              mock_acg(scopes) do |auth_header|
                allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                  .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                allow_any_instance_of(pws)
                  .to receive(:find_by_ssn).and_return({ file_nbr: nil })
                expect(power_of_attorney.file_data).to be_nil
                put("#{path}/#{power_of_attorney.id}",
                    params: base64_params, headers: headers.merge(auth_header))
                power_of_attorney.reload
                parsed = JSON.parse(response.body)
                expect(power_of_attorney.file_data).to be_nil
                expect(response).to have_http_status(:unprocessable_entity)
                expect(parsed['errors'].first['title']).to eq('Unprocessable Entity')
                expect(parsed['errors'].first['detail']).to eq(error_detail)
              end
            end
          end

          context "when 'file_nbr' in the BGS response is blank" do
            it 'returns a 422' do
              mock_acg(scopes) do |auth_header|
                allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                  .to receive(:check_request_ssn_matches_mpi).and_return(nil)
                allow_any_instance_of(pws)
                  .to receive(:find_by_ssn).and_return({ file_nbr: '' })
                expect(power_of_attorney.file_data).to be_nil
                put("#{path}/#{power_of_attorney.id}",
                    params: base64_params, headers: headers.merge(auth_header))
                power_of_attorney.reload
                parsed = JSON.parse(response.body)
                expect(power_of_attorney.file_data).to be_nil
                expect(response).to have_http_status(:unprocessable_entity)
                expect(parsed['errors'].first['title']).to eq('Unprocessable Entity')
                expect(parsed['errors'].first['detail']).to eq(error_detail)
              end
            end
          end
        end
      end

      context 'when no attachment is provided to the PUT endpoint' do
        it 'rejects the request for missing param' do
          mock_acg(scopes) do |auth_header|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            allow_any_instance_of(pws)
              .to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
            put("#{path}/#{power_of_attorney.id}", headers: headers.merge(auth_header))
            expect(response).to have_http_status(:bad_request)
            expect(response.parsed_body['errors'][0]['title']).to eq('Missing parameter')
            expect(response.parsed_body['errors'][0]['detail']).to eq('Must include attachment')
          end
        end
      end
    end

    describe '#validate' do
      before do
        Veteran::Service::Representative.new(representative_id: '56789', poa_codes: ['074'],
                                             first_name: 'Abraham', last_name: 'Lincoln').save!
      end

      it 'returns a response when valid' do
        mock_acg(scopes) do |auth_header|
          allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
            .to receive(:check_request_ssn_matches_mpi).and_return(nil)
          post "#{path}/validate", params: data, headers: headers.merge(auth_header)
          parsed = JSON.parse(response.body)
          expect(parsed['data']['attributes']['status']).to eq('valid')
          expect(parsed['data']['type']).to eq('powerOfAttorneyValidation')
        end
      end

      it 'returns a response when invalid' do
        mock_acg(scopes) do |auth_header|
          post "#{path}/validate", params: { data: { attributes: nil } }.to_json, headers: headers.merge(auth_header)
          parsed = JSON.parse(response.body)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(parsed['errors']).not_to be_empty
        end
      end

      it 'responds properly when JSON parse error' do
        mock_acg(scopes) do |auth_header|
          post "#{path}/validate", params: 'hello', headers: headers.merge(auth_header)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'when the lighthouse_claims_api_poa_dependent_claimants feature is enabled' do
        before do
          Flipper.enable(:lighthouse_claims_api_poa_dependent_claimants)
        end

        context 'and the request includes a dependent claimant' do
          it 'calls validate_poa_code_exists! and validate_dependent_by_participant_id!' do
            mock_acg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:validate_json_schema).and_return(nil)

              expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                .to receive(:validate_poa_code_exists!)
              expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                .to receive(:validate_dependent_by_participant_id!)

              post "#{path}/validate", params: data_with_claimant, headers: headers.merge(auth_header)
            end
          end
        end

        context 'and the request does not include a dependent claimant' do
          it 'calls neither validate_poa_code_exists! nor validate_dependent_by_participant_id!' do
            mock_acg(scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
                .to receive(:check_request_ssn_matches_mpi).and_return(nil)

              expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                .not_to receive(:validate_poa_code_exists!)
              expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
                .not_to receive(:validate_dependent_by_participant_id!)

              post "#{path}/validate", params: data, headers: headers.merge(auth_header)
            end
          end
        end
      end

      context 'when the lighthouse_claims_api_poa_dependent_claimants feature is disabled' do
        before do
          Flipper.disable(:lighthouse_claims_api_poa_dependent_claimants)
        end

        it 'calls neither validate_poa_code_exists! nor validate_dependent_by_participant_id!' do
          mock_acg(scopes) do |auth_header|
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:check_request_ssn_matches_mpi).and_return(nil)
            allow_any_instance_of(ClaimsApi::V1::Forms::PowerOfAttorneyController)
              .to receive(:validate_json_schema).and_return(nil)

            expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
              .not_to receive(:validate_poa_code_exists!)
            expect_any_instance_of(ClaimsApi::DependentClaimantVerificationService)
              .not_to receive(:validate_dependent_by_participant_id!)

            post "#{path}/validate", params: data_with_claimant, headers: headers.merge(auth_header)
          end
        end
      end
    end

    describe '#active' do
      let(:bgs_poa_verifier) { BGS::PowerOfAttorneyVerifier.new(nil) }

      context 'when there is no BGS active power of attorney' do
        before do
          Veteran::Service::Representative.new(representative_id: '00000', poa_codes: ['074'], first_name: 'Abraham',
                                               last_name: 'Lincoln').save!
        end

        it 'returns a 404' do
          mock_acg(scopes) do |auth_header|
            allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
            expect(bgs_poa_verifier).to receive(:current_poa_code).and_return(nil).once
            get("#{path}/active", params: nil, headers: headers.merge(auth_header))
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      context 'when there is a BGS active power of attorney' do
        before do
          Veteran::Service::Representative.new(representative_id: '11111', poa_codes: ['074'], first_name: 'Abraham',
                                               last_name: 'Lincoln').save!
        end

        let(:representative_info) do
          {
            name: 'Abraham Lincoln',
            phone_number: '555-555-5555'
          }
        end

        it 'returns a 200' do
          mock_acg(scopes) do |auth_header|
            allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
            expect(bgs_poa_verifier).to receive(:current_poa_code).and_return('HelloWorld').exactly(3).times
            expect(bgs_poa_verifier).to receive(:previous_poa_code).and_return(nil)
            expect_any_instance_of(
              ClaimsApi::V1::Forms::PowerOfAttorneyController
            ).to receive(:build_representative_info).and_return(representative_info)
            get("#{path}/active", params: nil, headers: headers.merge(auth_header))

            parsed = JSON.parse(response.body)
            expect(response).to have_http_status(:ok)
            expect(parsed['data']['attributes']['representative']['service_organization']['poa_code'])
              .to eq('HelloWorld')
          end
        end
      end

      context 'when a non-accredited representative and non-veteran request active power of attorney' do
        it 'returns a 403' do
          mock_acg(scopes) do |auth_header|
            get("#{path}/active", params: nil, headers: headers.merge(auth_header))
            expect(response).to have_http_status(:forbidden)
          end
        end
      end

      describe 'additional POA info' do
        before do
          Veteran::Service::Representative.new(representative_id: '22222',
                                               poa_codes: ['074'], first_name: 'Abraham', last_name: 'Lincoln').save!
        end

        context 'when representative is part of an organization' do
          it "returns the organization's name and phone" do
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(
                ClaimsApi::V1::Forms::PowerOfAttorneyController
              ).to receive(:validate_user_is_accredited!).and_return(nil)
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              expect(bgs_poa_verifier).to receive(:current_poa_code).and_return('HelloWorld').exactly(3).times
              expect(bgs_poa_verifier).to receive(:previous_poa_code).and_return(nil)
              expect(Veteran::Service::Organization).to receive(:find_by).and_return(
                OpenStruct.new(name: 'Some Great Organization', phone: '555-555-5555')
              ).twice

              get("#{path}/active", params: nil, headers: headers.merge(auth_header))

              parsed = JSON.parse(response.body)

              expect(response).to have_http_status(:ok)
              expect(parsed['data']['attributes']['representative']['service_organization']['organization_name'])
                .to eq('Some Great Organization')
              expect(parsed['data']['attributes']['representative']['service_organization']['first_name'])
                .to eq(nil)
              expect(parsed['data']['attributes']['representative']['service_organization']['last_name'])
                .to eq(nil)
              expect(parsed['data']['attributes']['representative']['service_organization']['phone_number'])
                .to eq('555-555-5555')
            end
          end
        end

        context 'when representative is not part of an organization' do
          it "returns the representative's name and phone" do
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(
                ClaimsApi::V1::Forms::PowerOfAttorneyController
              ).to receive(:validate_user_is_accredited!).and_return(nil)
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              expect(bgs_poa_verifier).to receive(:current_poa_code).and_return('HelloWorld').exactly(3).times
              expect(bgs_poa_verifier).to receive(:previous_poa_code).and_return(nil)
              allow(Veteran::Service::Representative).to receive(:where).and_return(
                [
                  OpenStruct.new(
                    first_name: 'Tommy',
                    last_name: 'Testerson',
                    phone: '555-555-5555'
                  )
                ]
              )

              get("#{path}/active", params: nil, headers: headers.merge(auth_header))

              parsed = JSON.parse(response.body)

              expect(response).to have_http_status(:ok)
              expect(parsed['data']['attributes']['representative']['service_organization']['first_name'])
                .to eq('Tommy')
              expect(parsed['data']['attributes']['representative']['service_organization']['last_name'])
                .to eq('Testerson')
              expect(parsed['data']['attributes']['representative']['service_organization']['organization_name'])
                .to eq(nil)
              expect(parsed['data']['attributes']['representative']['service_organization']['phone_number'])
                .to eq('555-555-5555')
            end
          end
        end

        context 'when representative POA code not found in OGC scraped data' do
          it 'returns a 404' do
            mock_acg(scopes) do |auth_header|
              expect_any_instance_of(
                ClaimsApi::V1::Forms::PowerOfAttorneyController
              ).to receive(:validate_user_is_accredited!).and_return(nil)
              allow(BGS::PowerOfAttorneyVerifier).to receive(:new).and_return(bgs_poa_verifier)
              expect(bgs_poa_verifier).to receive(:current_poa_code).and_return('HelloWorld').twice
              allow(Veteran::Service::Organization).to receive(:find_by).and_return(nil)
              allow(Veteran::Service::Representative).to receive(:where).and_return([])

              get("#{path}/active", params: nil, headers: headers.merge(auth_header))

              expect(response).to have_http_status(:not_found)
            end
          end
        end
      end
    end
  end
end
