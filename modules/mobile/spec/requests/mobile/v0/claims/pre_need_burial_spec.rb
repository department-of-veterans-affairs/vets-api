# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::PreNeedBurial', type: :request do
  include SchemaMatchers

  describe 'POST /mobile/v0/claims/pre-need-burial' do
    Flipper.disable(:va_v3_contact_information_service)
    let!(:user) { sis_user(icn: '1012846043V576341') }
    let(:params) do
      { application: attributes_for(:burial_form) }
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
                                                             'schema 5e610c8c-e49f-54bb-8079-710b31a7928c',
                                                 'code' => '109',
                                                 'status' => '422' },
                                               { 'title' => 'Validation error',
                                                 'detail' => "The property '#/application/veteran/militaryStatus' " \
                                                             'value nil did not match one of the following values: A' \
                                                             ', I, D, S, R, E, O, V, X in schema ' \
                                                             '5e610c8c-e49f-54bb-8079-710b31a7928c',
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
