# frozen_string_literal: true

require 'watir'
require 'selenium-webdriver'
require 'json'
require_relative './constants/constants.rb'

# This service submits a form to the existing IRIS Oracle page
module Ask
  module Iris
    class OracleRPAService
      include Constants
      def initialize(request)
        @request = request
      end

      def submit_form
        @field_list = Ask::Iris::Mappers::ToOracle::FIELD_LIST

        browser = WatirConfig.new(URI)

        # Inquiry Topic, Type, and Question
        set_topic_inquiry_fields(browser)

        browser.select_dropdown_by_text(FORM_OF_ADDRESS_FIELD_NAME, FORM_OF_ADDRESS)

        @field_list.each do |field|
          parsed_form = @request.parsed_form
          value = read_value_for_field(field, parsed_form)

          transformed_value = field.transform(value)
          set_field_value(browser, field, transformed_value)

        end
        submit_form_to_oracle(browser)
        get_confirmation_number(browser)
      end

      private

      def set_field_value(browser, field, value)
        if field.field_type.eql? TEXT_FIELD
          browser.set_text_field(field.field_name, value)
          validate_email(browser, field, value) if field.field_name.include? 'email'
        elsif field.field_type.eql? DROPDOWN
          browser.select_dropdown_by_text(field.field_name, value)
        elsif field.field_type.eql? RADIO
          browser.set_yes_no_radio(field.field_name, value)
        end
      end

      def read_value_for_field(field, value)
        field.schema_key.split('.').each do |key|
          value = value[key]
        end
        value
      end

      def validate_email(browser, field, value)
        browser.tab
        browser.set_text_field((field.field_name + '_Validation'), value)
      end

      def submit_form_to_oracle(browser)
        browser.click_button_by_id(SUBMIT_FORM_BUTTON_ID)
        browser.click_button_by_text(CONFIRM_SUBMIT_BUTTON_TEXT)
      end

      def get_confirmation_number(browser)
        browser.get_text_from_element(BOLD_TAG, CONFIRMATION_NUMBER_MATCHER)
      end

      def set_topic_inquiry_fields(browser)
        topic_labels = get_topics
        select_topic(browser, topic_labels)

        if @request.parsed_form['topic']['vaMedicalCenter']
          browser.select_dropdown_by_value(MEDICAL_CENTER_DROPDOWN, @request.parsed_form['topic']['vaMedicalCenter'])
        end

        browser.click_button_by_id(INQUIRY_TYPE_BUTTON_ID)
        browser.click_link(@request.parsed_form['inquiryType'])

        browser.set_text_area(QUERY_FIELD_NAME, @request.parsed_form['query'])
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
          browser.click_button_by_id(TOPIC_BUTTON_ID)
          browser.click_link(label)
        end
      end
    end
  end
end
