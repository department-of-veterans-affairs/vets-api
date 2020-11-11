# frozen_string_literal: true

require 'watir'
require 'selenium-webdriver'
require 'json'

# This service submits a form to the existing IRIS Oracle page
class OracleRPAService
  def initialize(claim)
    @claim = claim
  end

  def submit_form
    file = File.read('app/services/iris_fields_mapping.json')

    browser = Watir::Browser.new :chrome, args: %w[--no-sandbox --disable-dev-shm-usage]
    browser.goto 'https://iris--tst.custhelp.com/app/ask'
    browser.window.resize_to 1024, 728

    # Inquiry Topic, Type, and Question
    select_topic(browser, ['Compensation (Service-Connected Bens)', 'Filing for compensation benefits'])
    browser.select_list(name: 'Incident.CustomFields.c.route_to_state').option(text: 'ALABAMA').select

    browser.button(id: 'rn_ProductCategoryInput_6_Category_Button').click
    browser.link(visible_text: @claim.parsed_form['inquiryType']).click

    browser.textarea(name: 'Incident.Threads').set @claim.parsed_form['query']

    browser.select_list(name: 'Incident.CustomFields.c.form_of_address').option(text: 'Dr.').select


    JSON.load(file).each do |field|
      value = @claim.parsed_form
      field['schemaKey'].split('.').each do |key|
        value = value[key]
      end
      puts 'Value is ', value
      if value === 'dependent'
        value = 'for the Dependent of a Veteran'
      end
      if value === 'email'
        value = 'E-Mail'
      end
      if value === 'USA'
        value = 'United States'
      end
      if value === 'IL'
        value = 'Illinois'
      end
      if field['fieldName'].include? 'date_of_birth'
        temp_value = value.split('-')
        value = temp_value[1] + '-' + temp_value[2] + '-' + temp_value[0]
      end
      if field['fieldName'].include? 'e_o_d'
        temp_value = value.split('-')
        value = temp_value[1] + '-' + temp_value[2] + '-' + temp_value[0]
      end
      if field['fieldName'].include? 'released_from_duty'
        temp_value = value.split('-')
        value = temp_value[1] + '-' + temp_value[2] + '-' + temp_value[0]
      end
      if field['fieldType'] === 'text_field'
        browser.text_field(name: field['fieldName']).set value
        if field['fieldName'].include? 'incomingemail'
          browser.send_keys :tab
          browser.text_field(name: 'Incident.CustomFields.c.incomingemail_Validation').set value
        end
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
    browser.button(id: 'rn_FormSubmit_58_Button').click
    browser.button(text: 'Finish Submitting Question').click
    browser.element(tag_name: 'b', visible_text: /#[0-9-]*/).inner_text
  end

  private

  def select_topic(browser, topic_labels)
    topic_labels.each do |label|
      browser.button(id: 'rn_ProductCategoryInput_3_Product_Button').click
      browser.link(visible_text: label).click
    end
  end
end
