# frozen_string_literal: true

require 'watir'
require 'selenium-webdriver'
require 'json'

# This service submits a form to the existing IRIS Oracle page

module Ask
  module Iris
    class OracleRPAService
      def initialize(request)
        @request = request
      end

      FORM_OF_ADDRESS = 'Dr.'

      def submit_form
        iris_constants = Ask::Iris::Constants::FieldMappings.new
        file = File.read('app/services/ask/iris/constants/field_names_mapping.json')

        browser = Watir::Browser.new :chrome, args: %w[--no-sandbox --disable-dev-shm-usage]
        browser.goto 'https://iris--tst.custhelp.com/app/ask'
        # Must be resized in order for watir to find fields on the very right side of the form
        browser.window.resize_to 1024, 728

        # Inquiry Topic, Type, and Question
        set_topic_inquiry_fields(browser)

        browser.select_list(name: 'Incident.CustomFields.c.form_of_address').option(text: FORM_OF_ADDRESS).select

        JSON.load(file).each do |field|
          value = @request.parsed_form
          field['schemaKey'].split('.').each do |key|
            value = value[key]
          end

          value = iris_constants.vet_status_mappings[value] if field['fieldName'].include? 'vet_status'
          value = iris_constants.contact_method_mappings[value] if field['fieldName'].include? 'form_of_response'
          value = iris_constants.state_mappings[value] if field['fieldName'].include? 'state'
          value = iris_constants.country_mappings[value] if field['fieldName'].include? 'country'

          if %w[date_of_birth e_o_d released_from_duty].any? { |date_field| field['fieldName'].include? date_field }
            value = transform_date(value)
          end
          if field['fieldType'] === 'text_field'
            browser.text_field(name: field['fieldName']).set value
            validate_email(browser, field, value) if field['fieldName'].include? 'email'
          elsif field['fieldType'] === 'select_list'
            browser.select_list(name: field['fieldName']).option(text: value).select
          elsif field['fieldType'] === 'radio'
            if value === true
              browser.radio(name: field['fieldName'], value: '1').set
            else
              browser.radio(name: field['fieldName'], value: '0').set
            end
          end
        end
        submit_form_to_oracle(browser)
      end

      private

      def validate_email(browser, field, value)
        browser.send_keys :tab
        browser.text_field(name: field['fieldName'] + '_Validation').set value
      end

      def submit_form_to_oracle(browser)
        browser.button(id: 'rn_FormSubmit_58_Button').click
        browser.button(text: 'Finish Submitting Question').click
        browser.element(tag_name: 'b', visible_text: /#[0-9-]*/).inner_text
      end

      def set_topic_inquiry_fields(browser)
        topic_labels = get_topics
        select_topic(browser, topic_labels)

        if @request.parsed_form['topic']['vaMedicalCenter']
          browser.select_list(name: 'Incident.CustomFields.c.medical_centers').option(value: @request.parsed_form['topic']['vaMedicalCenter']).select
        end

        browser.button(id: 'rn_ProductCategoryInput_6_Category_Button').click
        browser.link(visible_text: @request.parsed_form['inquiryType']).click

        browser.textarea(name: 'Incident.Threads').set @request.parsed_form['query']
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
          browser.button(id: 'rn_ProductCategoryInput_3_Product_Button').click
          browser.link(visible_text: label).click
        end
      end

      def transform_date(value)
        temp_value = value.split('-')
        temp_value[1] + '-' + temp_value[2] + '-' + temp_value[0]
      end
    end
  end
end
