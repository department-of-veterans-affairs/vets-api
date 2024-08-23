# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'

RSpec.describe 'Disability Claims PDF Generation', type: :request do
  let(:no_first_name_target_veteran) do
    OpenStruct.new(
      icn: '1012832025V743496',
      first_name: '',
      last_name: 'Ford',
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

  let(:no_first_last_name_target_veteran) do
    OpenStruct.new(
      icn: '1012832025V743496',
      first_name: '',
      last_name: '',
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
  end

  after do
    Timecop.return
  end

  def set_international_address(json, address_type)
    address_hash = address_type.reduce(json['data']['attributes']) { |acc, key| acc[key] }
    address_hash.merge!(
      'addressLine1' => '1-1',
      'addressLine2' => 'Yoyogi Kamizono-cho',
      'addressLine3' => 'Shibuya-ku',
      'city' => 'Tokyo',
      'internationalPostalCode' => '151-8557',
      'country' => 'Japan'
    )
    address_hash.delete('state')
  end

  describe 'POST #generatePDF/minimum-validations', vcr: 'claims_api/disability_comp' do
    let(:anticipated_separation_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:active_duty_end_date) { 2.days.from_now.strftime('%Y-%m-%d') }
    let(:data) do
      temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans',
                             'disability_compensation', 'form_526_generate_pdf_json_api.json').read
      temp = JSON.parse(temp)
      attributes = temp['data']['attributes']
      attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date
      attributes['serviceInformation']['servicePeriods'][-1]['activeDutyEndDate'] = active_duty_end_date

      temp.to_json
    end

    let(:schema) { Rails.root.join('modules', 'claims_api', 'config', 'schemas', 'v2', 'generate_pdf_526.json').read }
    let(:veteran_id) { '1012832025V743496' }
    let(:generate_pdf_scopes) { %w[system/526-pdf.override] }
    let(:invalid_scopes) { %w[claim.write claim.read] }
    let(:generate_pdf_path) { "/services/claims/v2/veterans/#{veteran_id}/526/generatePDF/minimum-validations" }
    let(:special_issues) { ['POW'] }

    context 'submission to generatePDF' do
      it 'returns a 200 response when successful' do
        mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
          post generate_pdf_path, params: data, headers: auth_header
          expect(response.header['Content-Disposition']).to include('filename')
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when specialIssues is not present for a disability' do
        it 'returns a 200 response' do
          json = JSON.parse data
          json['data']['attributes']['disabilities'][0]['specialIssues'] = special_issues
          data = json.to_json
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: data, headers: auth_header
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

      context 'when invalid JSON is submitted' do
        it 'returns a 422 response' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            post generate_pdf_path, params: {}, headers: auth_header
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      context 'handling for missing first and last name' do
        context 'without the first and last name present' do
          it 'does not allow the generatePDF call to occur' do
            mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(no_first_last_name_target_veteran)
              allow_any_instance_of(ClaimsApi::V2::Veterans::DisabilityCompensationController)
                .to receive(:veteran_middle_initial).and_return('')

              post generate_pdf_path, params: data, headers: auth_header
              expect(response).to have_http_status(:unprocessable_entity)
              expect(response.parsed_body['errors'][0]['detail']).to eq('Must have either first or last name')
            end
          end
        end

        context 'without the first name present' do
          it 'allows the generatePDF call to occur' do
            mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
              allow_any_instance_of(ClaimsApi::V2::ApplicationController)
                .to receive(:target_veteran).and_return(no_first_name_target_veteran)
              allow_any_instance_of(ClaimsApi::V2::Veterans::DisabilityCompensationController)
                .to receive(:veteran_middle_initial).and_return('')

              post generate_pdf_path, params: data, headers: auth_header
              expect(response).to have_http_status(:ok)
            end
          end
        end
      end

      context 'when the mailing address is international' do
        it 'returns a 200 response' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            json = JSON.parse(data)
            set_international_address(json, %w[veteranIdentification mailingAddress])
            data = json.to_json
            post(generate_pdf_path, params: data, headers: auth_header)
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'when the change of address is international' do
        it 'returns a 200 response' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            json = JSON.parse(data)
            set_international_address(json, ['changeOfAddress'])
            data = json.to_json
            post(generate_pdf_path, params: data, headers: auth_header)
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

      context 'when overflow text is not provided' do
        it 'responds with a 200' do
          mock_ccg_for_fine_grained_scope(generate_pdf_scopes) do |auth_header|
            json = JSON.parse(data)
            json['data']['attributes']['claimNotes'] = nil
            data = json.to_json
            post generate_pdf_path, params: data, headers: auth_header
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end
end
