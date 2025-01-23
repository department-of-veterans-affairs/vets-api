# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require_relative '../../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Claims::PreNeedsBurial::Cemeteries', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  describe 'GET /mobile/v0/claims/pre-need-burial/cemeteries' do
    let!(:user) { sis_user(icn: '1012846043V576341') }

    it 'responds to GET #index' do
      VCR.use_cassette('preneeds/cemeteries/gets_a_list_of_cemeteries') do
        get '/mobile/v0/claims/pre-need-burial/cemeteries', headers: sis_headers, params: nil
      end
      assert_schema_conform(200)
      expect(response.parsed_body['data'][0, 2]).to eq(
        [{ 'id' => '915',
           'type' => 'cemetery',
           'attributes' => { 'name' => 'ABRAHAM LINCOLN NATIONAL CEMETERY',
                             'type' => 'N' } },
         { 'id' => '400',
           'type' => 'cemetery',
           'attributes' => { 'name' => 'ALABAMA STATE VETERANS MEMORIAL CEMETERY',
                             'type' => 'S' } }]
      )
    end
  end
end
