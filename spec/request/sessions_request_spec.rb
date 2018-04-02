require 'rails_helper'

describe 'Sessions', type: :request do
  context 'SSO' do
    it 'uses external SAML IdP' do
      get '/sessions/idme/new'
      expect(response).to redirect_to(%r{idp\.example.com\/api\/saml\/auth})
      idp_uri = URI(response.headers['Location'])
      saml_idp_resp = Net::HTTP.get(idp_uri)

      saml_response = OneLogin::RubySaml::Response.new(saml_idp_resp)
      asserted_attributes = saml_response.attributes.attributes.keys.map(&:to_sym)
      expect(asserted_attributes).to match_array(%i[uid email])

      post '/auth/saml/callback', SAMLResponse: saml_idp_resp
      expect(response).to redirect_to('http://www.example.com/success')
    end
  end
end
