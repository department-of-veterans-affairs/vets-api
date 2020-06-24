module SAML
  module ValidationHelpers
    extend ActiveSupport::Concern

    def expect_saml_post_form(body, expected_action, expected_relay_state = nil)
      expect(body).to match(/form id=\"saml-form\"/)
      expect(body).to match("action=\"#{expected_action}\"")
      expect(body).to match(/input type=\"hidden\" name=\"SAMLRequest\"/)

      # TODO Add expects for relay state
      
    end
  end
end
