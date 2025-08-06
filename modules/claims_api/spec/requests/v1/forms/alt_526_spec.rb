# frozen_string_literal: true

# Specs in this file test the AltDisabilityCompensationValidations module
require 'rails_helper'
require_relative '../../../rails_helper'
require 'bgs_service/standard_data_service'

RSpec.describe 'ClaimsApi::V1::Forms::526', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1956-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write] }
  let(:multi_profile) do
    MPI::Responses::FindProfileResponse.new(
      status: :ok,
      profile: build(:mpi_profile, participant_id: nil, participant_ids: %w[123456789 987654321],
                                   birth_date: '19560506')
    )
  end
  let(:no_pid_profile) do
    MPI::Responses::FindProfileResponse.new(
      status: :ok,
      profile: build(:mpi_profile, participant_id: nil, edipi: '123456', participant_ids: %w[])
    )
  end

  before do
    stub_poa_verification
    Timecop.freeze(Time.zone.now)
    stub_claims_api_auth_token

    # Use true so that 526 points to the alternate validations when these tests run
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(true)
  end

  after do
    Timecop.return
  end

  describe '#526' do
    let(:claim_date) { (Time.zone.today - 1.day).to_s }
    let(:auto_cest_pdf_generation_disabled) { false }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_526_json_api.json').read
      temp = JSON.parse(temp)
      temp['data']['attributes']['autoCestPDFGenerationDisabled'] = auto_cest_pdf_generation_disabled
      temp['data']['attributes']['claimDate'] = claim_date
      temp['data']['attributes']['applicationExpirationDate'] = (Time.zone.today + 1.day).to_s

      temp.to_json
    end
    let(:path) { '/services/claims/v1/forms/526' }
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v1', '526.json').read }
    let(:parsed_codes) do
      {
        birls_id: '111985523',
        participant_id: '32397028'
      }
    end
    let(:add_response) { build(:add_person_response, parsed_codes:) }

    describe 'validations' do
      context "when 'claimDate' is included and after current date" do
        let(:claim_date_after) { (Time.zone.today + 1.day).to_s }

        it 'returns an error' do
          mock_acg(scopes) do |auth_header|
            VCR.use_cassette('claims_api/bgs/claims/claims') do
              VCR.use_cassette('claims_api/brd/countries') do
                json_data = JSON.parse data
                params = json_data
                params['data']['attributes']['claimDate'] = claim_date_after 
                post path, params: params.to_json, headers: headers.merge(auth_header)
                expect(response).to have_http_status(:bad_request)
              end
            end
          end
        end
      end
    end
  end
end
