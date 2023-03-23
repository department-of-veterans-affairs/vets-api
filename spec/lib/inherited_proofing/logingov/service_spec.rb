# frozen_string_literal: true

require 'rails_helper'
require 'inherited_proofing/logingov/service'

describe InheritedProofing::Logingov::Service do
  let(:auth_code) { SecureRandom.hex }

  describe '#render_auth' do
    let(:response) { subject.render_auth(auth_code:).to_s }

    it 'renders the oauth_get_form template' do
      expect(response).to include('form id="oauth-form"')
    end

    it 'includes the inherited_proofing_auth URL param' do
      expect(response).to include("id=\"inherited_proofing_auth\" value=\"#{auth_code}\"")
    end

    it 'directs to the Login.gov OAuth authorization page' do
      expect(response).to include('action="https://idp.int.identitysandbox.gov/openid_connect/authorize"')
    end
  end
end
