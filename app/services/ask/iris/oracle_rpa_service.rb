# frozen_string_literal: true

require 'watir'
require 'selenium-webdriver'
require 'json'
require_relative './constants/constants.rb'

# This service submits a form to the existing IRIS Oracle page
module Ask
  module Iris
    class OracleRPAService
      def initialize(request)
        @request = request
      end

      def submit_form
        @field_list = Ask::Iris::Mappers::ToOracle::FIELD_LIST

        browser = WatirConfig.new(Constants::URI)

        # Inquiry Topic, Type, and Question
        set_topic_inquiry_fields(browser)

        browser.select_dropdown_by_text(Constants::FORM_OF_ADDRESS_FIELD_NAME, Constants::FORM_OF_ADDRESS)

        @field_list.each do |field|
          parsed_form = @request.parsed_form
          value = read_value_for_field(field, parsed_form)

          transformed_value = field.transform(value)
          field.enter_into_form browser, transformed_value
        end
        submit_form_to_oracle(browser)
        get_confirmation_number(browser)
      end

      private

      def read_value_for_field(field, value)
        field.schema_key.split('.').each do |key|
          value = value[key]
        end
        value
      end

      # unused, can be deleted
      def validate_email(browser, field, value)
        browser.tab
        browser.set_text_field((field.field_name + '_Validation'), value)
      end

      def submit_form_to_oracle(browser)
        browser.click_button_by_id(Constants::SUBMIT_FORM_BUTTON_ID)
        browser.click_button_by_text(Constants::CONFIRM_SUBMIT_BUTTON_TEXT)
      end

      def get_confirmation_number(browser)
        browser.get_text_from_element(Constants::BOLD_TAG, Constants::CONFIRMATION_NUMBER_MATCHER)
      end

      def set_topic_inquiry_fields(browser)

        if @request.parsed_form['topic']['vaMedicalCenter']
          browser.select_dropdown_by_value(Constants::MEDICAL_CENTER_DROPDOWN, @request.parsed_form['topic']['vaMedicalCenter'])
        end

        browser.set_text_area(Constants::QUERY_FIELD_NAME, @request.parsed_form['query'])
      end

      def get_topics
        topics = @request.parsed_form['topic']
        topic_values = []
        if topics.key?('levelThree')
          topic_values.append(topics['levelOne'], topics['levelTwo'], topics['levelThree'])
        else
          topic_values.append(topics['levelOne'], topics['levelTwo'])
        end
      end

      def select_topic(browser, topic_labels)
        topic_labels.each do |label|
          browser.click_button_by_id(Constants::TOPIC_BUTTON_ID)
          browser.click_link(label)
        end
      end
    end
  end
end
