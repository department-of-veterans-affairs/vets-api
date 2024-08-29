# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::PreNeedBurial', type: :request do
  include SchemaMatchers

  describe 'POST /mobile/v0/claims/pre-need-burial' do
    let!(:user) { sis_user(icn: '1012846043V576341') }
    let(:params) do
      { application: attributes_for(:burial_form) }
    end

    context 'with valid input' do
      let(:submission_record) { Preneeds::PreneedSubmission.first }

      it 'returns details about submitted form' do
        VCR.use_cassette('preneeds/burial_forms/creates_a_pre_need_burial_form') do
          post '/mobile/v0/claims/pre-need-burial', headers: sis_headers, params:
        end
        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('preneeds/receive_applications')
        expect(response.parsed_body.dig('data', 'attributes', 'returnCode')).to eq(0)
        expect(response.parsed_body.dig('data', 'attributes',
                                        'returnDescription')).to eq('PreNeed Application Received Successfully.')
      end

      it 'creates a PreneedSubmission record' do
        VCR.use_cassette('preneeds/burial_forms/creates_a_pre_need_burial_form') do
          expect do
            post('/mobile/v0/claims/pre-need-burial', headers: sis_headers, params:)
          end.to change(Preneeds::PreneedSubmission, :count).by(1)
        end
        expect(response).to have_http_status(:ok)

        attributes = response.parsed_body.dig('data', 'attributes')
        expect(attributes['trackingNumber']).to eq(submission_record.tracking_number)
        expect(attributes['applicationUuid']).to eq(submission_record.application_uuid)
        expect(attributes['returnCode']).to eq(submission_record.return_code)
        expect(attributes['returnDescription']).to eq(submission_record.return_description)
      end
    end

    context 'with missing input fields' do
      it 'returns an with a 422 error' do
        params[:application][:veteran].delete(:military_status)
        post('/mobile/v0/claims/pre-need-burial', headers: sis_headers, params:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to eq({ 'errors' =>
                                              [{ 'title' => 'Validation error',
                                                 'detail' => "The property '#/application/veteran/militaryStatus' of " \
                                                             'type null did not match the following type: string in ' \
                                                             'schema 72d7bc55-042d-5bfd-8001-2b7c815c8e06',
                                                 'code' => '109',
                                                 'status' => '422' },
                                               { 'title' => 'Validation error',
                                                 'detail' => "The property '#/application/veteran/militaryStatus' " \
                                                             'value nil did not match one of the following values: A' \
                                                             ', I, D, S, R, E, O, V, X in schema ' \
                                                             '72d7bc55-042d-5bfd-8001-2b7c815c8e06',
                                                 'code' => '109',
                                                 'status' => '422' }] })
      end
    end

    context 'with invalid field data' do
      it 'returns 400 error' do
        VCR.use_cassette('preneeds/burial_forms/burial_form_with_invalid_applicant_address2') do
          params[:application][:applicant][:mailing_address][:address2] = '1' * 21
          post('/mobile/v0/claims/pre-need-burial', headers: sis_headers, params:)
        end

        expect(response).to have_http_status(:bad_request)

        errors = response.parsed_body.dig('errors', 0)
        expect(errors['title']).to eq('Operation failed')
        expect(errors['code']).to eq('VA900')
        expect(errors['source']).to eq('EOAS provided a general error response, check logs for original request body.')
        expect(errors['status']).to eq('400')
      end
    end
  end
end
