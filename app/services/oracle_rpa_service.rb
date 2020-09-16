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

    browser = Watir::Browser.new :chrome, args: %w[--headless --no-sandbox --disable-dev-shm-usage]
    browser.goto 'https://iris--tst.custhelp.com/app/ask'
    browser.window.resize_to 1024, 728

    # Inquiry Topic, Type, and Question
    select_topic(browser, ['Compensation (Service-Connected Bens)', 'Filing for compensation benefits'])
    browser.select_list(name: 'Incident.CustomFields.c.route_to_state').option(text: 'ALABAMA').select

    browser.button(id: 'rn_ProductCategoryInput_6_Category_Button').click
    browser.link(visible_text: @claim.parsed_form['inquiryType']).click
    browser.button(id: 'rn_ProductCategoryInput_6_Category_ConfirmButton').click

    browser.textarea(name: 'Incident.Threads').set @claim.parsed_form['query']

    JSON.load(file).each do |field|
      value = @claim.parsed_form
      field['schemaKey'].split('.').each do |key|
        value = value[key]
      end
      puts 'Value is ', value
      if field['fieldType'] === 'text_field'
        browser.text_field(name: field['fieldName']).set value
      elsif field['fieldType'] === 'select_list'
        browser.select_list(name: field['fieldName']).option(text: value).select
      end
    end
    0
  end

  private

  def select_topic(browser, topic_labels)
    browser.button(id: 'rn_ProductCategoryInput_3_Product_Button').click
    topic_labels.each do |label|
      browser.link(visible_text: label).click
    end
    browser.button(id: 'rn_ProductCategoryInput_3_Product_ConfirmButton').click
  end
end
