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
        iris_values = Ask::Iris::Mappers::ContactUsToIrisValues.new
        file = File.read('app/services/ask/iris/mappers/contact_us_to_iris_fields.json')

        browser = WatirConfig.new(URI)

        # Inquiry Topic, Type, and Question
        set_topic_inquiry_fields(browser)

        browser.select_dropdown_by_text(FORM_OF_ADDRESS_FIELD_NAME, FORM_OF_ADDRESS)

        JSON.load(file).each do |field|
          value = @request.parsed_form
          field['schemaKey'].split('.').each do |key|
            value = value[key]
          end

          value = iris_values.vet_status_mappings[value] if field['fieldName'].include? 'vet_status'
          value = iris_values.contact_method_mappings[value] if field['fieldName'].include? 'form_of_response'
          value = iris_values.state_mappings[value] if field['fieldName'].include? 'state'
          value = iris_values.country_mappings[value] if field['fieldName'].include? 'country'

          value = transform_date(value) if date_field? field['fieldName']

          if field['fieldType'].eql? TEXT_FIELD
            browser.set_text_field(field['fieldName'], value)
            validate_email(browser, field, value) if field['fieldName'].include? 'email'
          elsif field['fieldType'].eql? DROPDOWN
            browser.select_dropdown_by_text(field['fieldName'], value)
          elsif field['fieldType'].eql? RADIO
            browser.set_yes_no_radio(field['fieldName'], value)
          end
        end
        submit_form_to_oracle(browser)
        get_confirmation_number(browser)
      end

      private

      def validate_email(browser, field, value)
        browser.tab
        browser.set_text_field((field['fieldName'] + '_Validation'), value)
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

      def transform_date(value)
        temp_value = value.split('-')
        temp_value[1] + '-' + temp_value[2] + '-' + temp_value[0]
      end

      def date_field?(field)
        %w[date_of_birth e_o_d released_from_duty].any? { |date_field| field.include? date_field }
      end
    end
  end
end
