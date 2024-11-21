# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::PreNeedBurial', type: :request do
  include SchemaMatchers
  include CommitteeHelper

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
        assert_schema_conform(422)
        expect(response.parsed_body).to eq({ 'errors' =>
                                              [{ 'title' => 'Validation error',
                                                 'detail' => "The property '#/application/veteran/militaryStatus' of " \
                                                             'type null did not match the following type: string in ' \
                                                             'schema f7285ec8-ff50-51f5-b481-fc3d2ad5c1bc',
                                                 'code' => '109',
                                                 'status' => '422' },
                                               { 'title' => 'Validation error',
                                                 'detail' => "The property '#/application/veteran/militaryStatus' " \
                                                             'value nil did not match one of the following values: A' \
                                                             ', I, D, S, R, E, O, V, X in schema ' \
                                                             'f7285ec8-ff50-51f5-b481-fc3d2ad5c1bc',
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

        assert_schema_conform(400)

        errors = response.parsed_body.dig('errors', 0)
        expect(errors['title']).to eq('Operation failed')
        expect(errors['code']).to eq('VA900')
        expect(errors['source']).to eq('EOAS provided a general error response, check logs for original request body.')
        expect(errors['status']).to eq('400')
      end
    end
  end
end
