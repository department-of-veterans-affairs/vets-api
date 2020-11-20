# frozen_string_literal: true

require 'watir'
require 'selenium-webdriver'
require 'json'

# This service submits a form to the existing IRIS Oracle page
module Ask
  module Iris
    class OracleRPAService
      include Constants::Constants

      def self.submit_form(form)
        browser = WatirConfig.new(URI)

        form.fields.each do |field|
          field.enter_into_form browser
        end
        submit_form_to_oracle(browser)
        get_confirmation_number(browser)
      end

      private

      def self.submit_form_to_oracle(browser)
        browser.click_button_by_id(SUBMIT_FORM_BUTTON_ID)
        browser.click_button_by_text(CONFIRM_SUBMIT_BUTTON_TEXT)
      end

      def self.get_confirmation_number(browser)
        browser.get_text_from_element(BOLD_TAG, CONFIRMATION_NUMBER_MATCHER)
      end
    end
  end
end
