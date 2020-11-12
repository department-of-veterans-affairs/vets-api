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
    # Must be resized in order for watir to find fields on the very right side of the form
    browser.window.resize_to 1024, 728

    # Inquiry Topic, Type, and Question
    set_topic_inquiry_fields(browser)

    browser.select_list(name: 'Incident.CustomFields.c.form_of_address').option(text: 'Dr.').select


    JSON.load(file).each do |field|
      value = @claim.parsed_form
      field['schemaKey'].split('.').each do |key|
        value = value[key]
      end
      if field['fieldName'].include? 'vet_status'
        value = transform_vet_status(value)
      end
      if field['fieldName'].include? 'form_of_response'
        value = transform_contact_method(value)
      end
      if field['fieldName'].include? 'state'
        value = transform_state(value)
      end
      if value === 'USA'
        value = 'United States'
      end
      if %w[date_of_birth e_o_d released_from_duty].any? {|date_field| field['fieldName'].include? date_field}
        value = transform_date(value)
      end
      if field['fieldType'] === 'text_field'
        browser.text_field(name: field['fieldName']).set value
        if field['fieldName'].include? 'email'
          browser.send_keys :tab
          browser.text_field(name: field['fieldName'] + '_Validation').set value
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

  def set_topic_inquiry_fields(browser)
    topic_labels = get_topics
    select_topic(browser, topic_labels)

    if @claim.parsed_form['topic']['vaMedicalCenter']
      browser.select_list(name: 'Incident.CustomFields.c.medical_centers').option(value: @claim.parsed_form['topic']['vaMedicalCenter']).select
    end

    browser.button(id: 'rn_ProductCategoryInput_6_Category_Button').click
    browser.link(visible_text: @claim.parsed_form['inquiryType']).click

    browser.textarea(name: 'Incident.Threads').set @claim.parsed_form['query']
  end

  def get_topics
    topics = @claim.parsed_form['topic']
    topic_values = []
    topic_values.append(topics['levelOne'], topics['levelTwo'], topics['levelThree'])
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

  def transform_vet_status(value)
    vet_status_mapping = {'dependent' => 'for the Dependent of a Veteran', 'general' => 'General Question (Vet Info Not Needed)', 'vet' => 'for Myself as a Veteran (I am the Vet)', 'behalf of vet' => 'for, about, or on behalf of a Veteran'}
    vet_status_mapping[value]
  end

  def transform_contact_method(value)
    contact_method_mapping = {'email' => 'E-Mail', 'phone' => 'Telephone', 'mail' => 'US Mail'}
    contact_method_mapping[value]
  end

  def transform_state(value)
    state_mapping = {
      'AL' => 'Alabama',
      'AK' => 'Alaska',
      'AZ' => 'Arizona',
      'AR' => 'Arkansas',
      'CA' => 'California',
      'CO' => 'Colorado',
      'CT' => 'Connecticut',
      'DE' => 'Delaware',
      'DC' => 'District Of Columbia',
      'FL' => 'Florida',
      'GA' => 'Georgia',
      'HI' => 'Hawaii',
      'ID' => 'Idaho',
      'IL' => 'Illinois',
      'IN' => 'Indiana',
      'IA' => 'Iowa',
      'KS' => 'Kansas',
      'KY' => 'Kentucky',
      'LA' => 'Louisiana',
      'ME' => 'Maine',
      'MD' => 'Maryland',
      'MA' => 'Massachusetts',
      'MI' => 'Michigan',
      'MN' => 'Minnesota',
      'MS' => 'Mississippi',
      'MO' => 'Missouri',
      'MT' => 'Montana',
      'NE' => 'Nebraska',
      'NV' => 'Nevada',
      'NH' => 'New Hampshire',
      'NJ' => 'New Jersey',
      'NM' => 'New Mexico',
      'NY' => 'New York',
      'NC' => 'North Carolina',
      'ND' => 'North Dakota',
      'OH' => 'Ohio',
      'OK' => 'Oklahoma',
      'OR' => 'Oregon',
      'PA' => 'Pennsylvania',
      'RI' => 'Rhode Island',
      'SC' => 'South Carolina',
      'SD' => 'South Dakota',
      'TN' => 'Tennessee',
      'TX' => 'Texas',
      'UT' => 'Utah',
      'VT' => 'Vermont',
      'VA' => 'Virginia',
      'WA' => 'Washington',
      'WV' => 'West Virginia',
      'WI' => 'Wisconsin',
      'WY' => 'Wyoming',
      'AS' => 'American Samoa',
      'AA' => 'Armed Forces Americas (AA)',
      'AE' => 'Armed Forces Europe (AE)',
      'AP' => 'Armed Forces Pacific (AP)',
      'FM' => 'Federated States Of Micronesia',
      'GU' => 'Guam',
      'MH' => 'Marshall Islands',
      'MP' => 'Northern Mariana Islands',
      'PW' => 'Palau',
      'PR' => 'Puerto Rico',
      'VI' => 'Virgin Islands'
    }

    state_mapping[value]
  end
end
