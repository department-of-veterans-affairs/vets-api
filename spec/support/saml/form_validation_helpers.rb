# frozen_string_literal: true

module SAML
  module ValidationHelpers
    extend ActiveSupport::Concern

    def expect_oauth_post_form(body, value, expected_action)
      doc = Nokogiri::HTML(body)
      expect(doc.at_css('form').attributes['id'].value).to eq(value)
      expect(doc.at_css('form').attributes['action'].value).to eq(expected_action)
    end

    def expect_saml_post_form(body, expected_action, expected_relay_state = nil)
      doc = Nokogiri::HTML(body)
      expect(doc.at_css('form').attributes['id'].value).to eq('saml-form')
      expect(doc.at_css('form').attributes['action'].value).to eq(expected_action)

      expect(doc.at_css('input[name=SAMLRequest]')).to be_truthy
      if expected_relay_state.present?
        expect(doc.at_css('input[name=RelayState]').attributes['value'].value).to eq(expected_relay_state.to_json)
      end
    end

    def expect_saml_form_parameters(params, expected_relay_state = nil)
      expect(params['SAMLRequest']).to be_truthy
      expect(params['RelayState']).to eq(expected_relay_state.to_json) if expected_relay_state.present?
    end
  end
end
