# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/idme/service'

describe SignIn::Idme::Service do
  let(:code) { '04e3f01f11764b50becb0cdcb618b804' }
  let(:token) do
    {
      access_token: '0f5ebddd60d0451782214e6705cac5d1',
      token_type: 'bearer',
      expires_in: 300,
      scope: 'http://idmanagement.gov/ns/assurance/loa/3',
      refresh_token: '26f282c510a740bb9c27aeed65fc08c4',
      refresh_expires_in: 604_800
    }
  end
  let(:user_info) do
    OpenStruct.new(
      {
        iss: 'https://api.idmelabs.com/oidc',
        sub: '6400bbf301eb4e6e95ccea7693eced6f',
        aud: 'dde0b5b8bfc023a093830e64ef83f148',
        exp: 1_647_499_198,
        iat: 1_647_481_182,
        credential_aal_highest: 2,
        credential_ial_highest: 'classic_loa3',
        birth_date: '1950-10-04',
        email: 'vets.gov.user+228@gmail.com',
        fname: 'MARK',
        social: '796104437',
        lname: 'WEBB',
        level_of_assurance: 3,
        multifactor: true,
        credential_aal: 2,
        credential_ial: 'classic_loa3',
        uuid: '6400bbf301eb4e6e95ccea7693eced6f'
      }
    )
  end
  let(:success_callback_url) { 'http://localhost:3001/auth/login/callback?type=logingov' }
  let(:failure_callback_url) { 'http://localhost:3001/auth/login/callback?auth=fail&code=007' }
  let(:state) { 'some-state' }

  describe '#render_auth' do
    let(:response) { subject.render_auth(state: state).to_s }

    it 'renders the oauth_get_form template' do
      expect(response).to include('form id="oauth-form"')
    end

    it 'directs to the Id.me OAuth authorization page' do
      expect(response).to include('action="https://api.idmelabs.com/oauth/authorize"')
    end
  end

  describe '#token' do
    it 'returns an access token' do
      VCR.use_cassette('identity/idme_200_responses') do
        expect(subject.token(code)).to eq(token)
      end
    end
  end

  describe '#user_info' do
    it 'returns a user attributes' do
      VCR.use_cassette('identity/idme_200_responses') do
        expect(subject.user_info(token)).to eq(user_info)
      end
    end
  end
end
