# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'
require 'saml/responses/login'

RSpec.describe SAML::Responses::Login do
  include SAML::ResponseBuilder

  status_detail = '<samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Responder"></samlp:StatusCode>'\
                  '<samlp:StatusDetail>'\
                  '<fim:FIMStatusDetail MessageID="could_not_perform_token_exchange"></fim:FIMStatusDetail>'\
                  '</samlp:StatusDetail>'
  no_detail = '<samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success" />'

  let(:document_with_detail) { document_status_detail(status_detail) }
  let(:document_no_detail) { document_status_detail(no_detail) }

  describe '#status_detail' do
    it 'returns status_detail when found' do
      saml_response = SAML::Responses::Login.new(document_with_detail.to_s)
      expect(saml_response.status_detail).to eq("<fim:FIMStatusDetail MessageID='could_not_perform_token_exchange'/>")
    end

    it 'returns nil when not found' do
      saml_response = SAML::Responses::Login.new(document_no_detail.to_s)
      expect(saml_response.status_detail).to be_nil
    end
  end
end
