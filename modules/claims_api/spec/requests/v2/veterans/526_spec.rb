# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'

RSpec.describe 'ClaimsApi::V2::Veterans::526', type: :request do
  let(:scopes) { %w[claim.write claim.read] }
  let(:claim_date) { Time.find_zone!('Central Time (US & Canada)').today }
  let(:target_veteran) do
    OpenStruct.new(
      icn: '1012832025V743496',
      first_name: 'Wesley',
      last_name: 'Ford',
      middle_name: 'John',
      birth_date: '19630211',
      loa: { current: 3, highest: 3 },
      edipi: nil,
      ssn: '796043735',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1012832025V743496',
        profile: OpenStruct.new(ssn: '796043735')
      )
    )
  end

  before do
    Timecop.freeze(Time.zone.now)
    allow_any_instance_of(ClaimsApi::EVSSService::Base).to receive(:submit).and_return OpenStruct.new(claimId: 1337)
    allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_enable_FES).and_return(false)
  end

  after do
    Timecop.return
  end

  describe '#526', vcr: 'claims_api/disability_comp' do
    let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:active_duty_end_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                             'form_526_json_api.json').read
      temp = JSON.parse(temp)
      attributes = temp['data']['attributes']
      attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
      attributes['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] = active_duty_end_date

      temp.to_json
    end
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
    let(:veteran_id) { '1013062086V794840' }

    context 'validate endpoint' do
      let(:veteran_id) { '1012832025V743496' }
      let(:validation_path) { "/services/claims/v2/veterans/#{veteran_id}/526/validate" }

      it 'returns a successful response when valid' do
        mock_ccg(scopes) do |auth_header|
          post validation_path, params: data, headers: auth_header
          expect(response).to have_http_status(:ok)
          parsed = JSON.parse(response.body)
          expect(parsed['data']['type']).to eq('claims_api_auto_established_claim_validation')
          expect(parsed['data']['attributes']['status']).to eq('valid')
        end
      end
    end

    describe '#generate_pdf' do
      let(:invalid_scopes) { %w[claim.write claim.read] }
      let(:generate_pdf_scopes) { %w[system/526-pdf.override] }
      let(:generate_pdf_path) { "/services/claims/v2/veterans/#{veteran_id}/526/generatePDF/minimum-validations" }

      context 'valid data' do
        it 'responds with a 200' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response.header['Content-Disposition']).to include('filename')
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'invalid scopes' do
        it 'returns a 401 unauthorized' do
          mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end

      context 'without the first and last name present' do
        it 'does not allow the generatePDF call to occur' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            target_veteran.first_name = ''
            target_veteran.last_name = ''
            allow_any_instance_of(ClaimsApi::V2::ApplicationController)
              .to receive(:target_veteran).and_return(target_veteran)

            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.parsed_body['errors'][0]['detail']).to eq('Must have either first or last name')
          end
        end
      end

      context 'without the first name present' do
        it 'allows the generatePDF call to occur' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            target_veteran.first_name = ''
            allow_any_instance_of(ClaimsApi::V2::ApplicationController)
              .to receive(:target_veteran).and_return(target_veteran)

            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'when the PDF string is not generated' do
        it 'returns a 422 response when empty object is returned' do
          allow_any_instance_of(ClaimsApi::V2::Veterans::DisabilityCompensationController)
            .to receive(:generate_526_pdf)
            .and_return({})

          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        it 'returns a 422 response if nil gets returned' do
          allow_any_instance_of(ClaimsApi::V2::Veterans::DisabilityCompensationController)
            .to receive(:generate_526_pdf)
            .and_return(nil)

          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end
  end

  describe 'POST #submit not using md5 lookup',
           skip: 'Disabling tests for deactivated /veterans/{veteranId}/526 endpoint' do
    let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:active_duty_end_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                             'form_526_json_api.json').read
      temp = JSON.parse(temp)
      attributes = temp['data']['attributes']
      attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
      attributes['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] = active_duty_end_date

      temp.to_json
    end
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
    let(:veteran_id) { '1013062086V794840' }
    let(:submit_path) { "/services/claims/v2/veterans/#{veteran_id}/526" }

    it 'creates a new claim if duplicate submit occurs (does not use md5 lookup)' do
      mock_ccg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/disability_comp') do
          json = JSON.parse(data)
          post submit_path, params: json.to_json, headers: auth_header
          expect(response).to have_http_status(:accepted)
          first_submit_parsed = JSON.parse(response.body)
          @original_id = first_submit_parsed['data']['id']
        end
      end
      mock_ccg(scopes) do |auth_header|
        VCR.use_cassette('claims_api/disability_comp') do
          json = JSON.parse(data)
          post submit_path, params: json.to_json, headers: auth_header
          expect(response).to have_http_status(:accepted)
          duplicate_submit_parsed = JSON.parse(response.body)
          duplicate_id = duplicate_submit_parsed['data']['id']
          expect(@original_id).not_to eq(duplicate_id)
        end
      end
    end
  end

  describe 'POST #synchronous' do
    let(:veteran_id) { '1012832025V743496' }
    let(:synchronous_path) { "/services/claims/v2/veterans/#{veteran_id}/526/synchronous" }
    let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:active_duty_end_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                             'form_526_json_api.json').read
      temp = JSON.parse(temp)
      attributes = temp['data']['attributes']
      attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
      attributes['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] = active_duty_end_date

      temp.to_json
    end
    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', '526.json').read }
    let(:synchronous_scopes) { %w[system/526.override system/claim.write] }
    let(:invalid_scopes) { %w[system/526-pdf.override] }
    let(:meta) do
      { transactionId: '00000000-0000-0000-000000000000' }
    end

    context 'submission to synchronous' do
      context 'with a transaction_id' do
        context 'present' do
          it 'saves the transaction ID on the claim record' do
            mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
              VCR.use_cassette('claims_api/disability_comp') do
                json = JSON.parse data
                json['meta'] = meta
                data = json.to_json
                post synchronous_path, params: data, headers: auth_header

                parsed_res = JSON.parse(response.body)
                claim_id = parsed_res['data']['id']
                aec = ClaimsApi::AutoEstablishedClaim.find(claim_id)

                expect(aec.transaction_id).to eq(meta[:transactionId])
                expect(parsed_res['meta']['transactionId']).to eq(meta[:transactionId])
                expect(response).to have_http_status(:accepted)
              end
            end
          end
        end

        context 'absent' do
          it 'has a null transaction ID on the claim record' do
            mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
              VCR.use_cassette('claims_api/disability_comp') do
                post synchronous_path, params: data, headers: auth_header

                parsed_res = JSON.parse(response.body)
                claim_id = parsed_res['data']['id']
                aec = ClaimsApi::AutoEstablishedClaim.find(claim_id)

                expect(aec.transaction_id).to be_nil
                expect(parsed_res).not_to have_key('meta')
                expect(response).to have_http_status(:accepted)
              end
            end
          end
        end
      end

      it 'returns an empty test object' do
        mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
          VCR.use_cassette('claims_api/disability_comp') do
            post synchronous_path, params: data, headers: auth_header

            parsed_res = JSON.parse(response.body)
            expect(parsed_res['data']['attributes']).to include('claimId')
          end
        end
      end

      it 'returns a 202 response when successful' do
        mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
          VCR.use_cassette('claims_api/disability_comp') do
            post synchronous_path, params: data, headers: auth_header

            expect(response).to have_http_status(:accepted)
          end
        end
      end

      it 'returns a 401 unauthorized with incorrect scopes' do
        mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
          post synchronous_path, params: data, headers: auth_header

          expect(response).to have_http_status(:unauthorized)
        end
      end

      it 'returns a 202 when the s3 upload is mocked' do
        with_settings(Settings.claims_api.benefits_documents, use_mocks: true) do
          mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
            VCR.use_cassette('claims_api/disability_comp') do
              post synchronous_path, params: data, headers: auth_header

              expect(response).to have_http_status(:accepted)
            end
          end
        end
      end
    end

    context 'handling for missing first and last name' do
      context 'without the first and last name present' do
        it 'does not allow the submit to occur' do
          mock_ccg_for_fine_grained_scope(synchronous_scopes) do |auth_header|
            VCR.use_cassette('claims_api/disability_comp') do
              target_veteran.first_name = ''
              target_veteran.last_name = ''
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(target_veteran)
              post synchronous_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.parsed_body['errors'][0]['detail']).to eq('Missing first and last name')
            end
          end
        end
      end
    end
  end
end
