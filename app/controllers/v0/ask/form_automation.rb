require 'watir'
require 'webdrivers'

browser = Watir::Browser.new :chrome, headless: true
browser.goto 'https://iris--tst.custhelp.com/app/ask'

request = {
  firstName: 'jane',
  lastName: 'doe',
  middleInitial: 'X',
  phoneNumber: '0001112222',
  city: 'Edgebrook',
  street: '100 Oak Drive',
  zipcode: '60608',
  email: 'jane.doe@va.gov',
  dep_firstName: 'jim',
  dep_lastName: 'doe',
  dep_middleInitial: 'X',
  dep_phoneNumber: '0001112222',
  dep_city: 'Edgebrook',
  dep_street: '100 Oak Drive',
  dep_zipcode: '60608',
  dep_email: 'jim.doe@va.gov',
  vet_firstName: 'sammy',
  vet_lastName: 'doe',
  vet_middleInitial: 'X',
  vet_phoneNumber: '0001112222',
  vet_city: 'Edgebrook',
  vet_street: '100 Oak Drive',
  vet_zipcode: '60608',
  vet_email: 'sammy.doe@va.gov',
  ssn: '111223333',
  claim_number: '1234567',
  service_number: '123456789012',
  date_of_birth: '01-01-1970',
  e_o_d: '01-01-2003',
  released_from_duty: '01-01-2009'
}

def select_topic(browser, topic_labels)
  browser.button(id: 'rn_ProductCategoryInput_3_Product_Button').click
  topic_labels.each do |label|
    browser.link(visible_text: label).click
  end
  browser.button(id: 'rn_ProductCategoryInput_3_Product_ConfirmButton').click
end

# Inquiry Topic, Type, and Question
select_topic(browser, ['Compensation (Service-Connected Bens)', 'Filing for compensation benefits'])
browser.select_list(name: 'Incident.CustomFields.c.route_to_state').option(text: 'ALABAMA').select

browser.button(id: 'rn_ProductCategoryInput_6_Category_Button').click
browser.link(visible_text: 'Question').click
browser.button(id: 'rn_ProductCategoryInput_6_Category_ConfirmButton').click

browser.textarea(name: 'Incident.Threads').set 'This is our test question'

# Relationship to Veteran
browser.select_list(name: 'Incident.CustomFields.c.vet_status').option(text: 'for the Dependent of a Veteran').select
browser.radio(id: 'rn_SelectionInput_9_Incident.CustomFields.c.inquirer_is_dependent_0').label.click
browser.select_list(name: 'Incident.CustomFields.c.relation_to_vet').option(text: 'Other').select
browser.radio(id: 'rn_SelectionInput_11_Incident.CustomFields.c.vet_dead_0').label.click

# Your Contact Information
browser.select_list(name: 'Incident.CustomFields.c.form_of_address').option(text: 'Dr.').select
browser.text_field(name: 'Incident.CustomFields.c.first_name').set request[:firstName]
browser.text_field(name: 'Incident.CustomFields.c.middle_initial').set request[:middleInitial]
browser.text_field(name: 'Incident.CustomFields.c.last_name').set request[:lastName]
browser.select_list(name: 'Incident.CustomFields.c.suffix_menu').option(text: 'III').select
browser.text_field(name: 'Incident.CustomFields.c.incomingemail').set request[:email]
browser.send_keys :tab
browser.text_field(name: 'Incident.CustomFields.c.incomingemail_Validation').set request[:email]
browser.text_field(name: 'Incident.CustomFields.c.telephone_number').set request[:phoneNumber]
browser.select_list(name: 'Incident.CustomFields.c.country').option(text: 'United States').select
browser.select_list(name: 'Incident.CustomFields.c.state').option(text: 'Illinois').select
browser.text_field(name: 'Incident.CustomFields.c.city').set request[:city]
browser.text_field(name: 'Incident.CustomFields.c.street').set request[:street]
browser.text_field(name: 'Incident.CustomFields.c.zipcode').set request[:zipcode]

# Dependent Information
browser.select_list(name: 'Incident.CustomFields.c.dep_relation_to_vet').option(text: 'Other').select
browser.select_list(name: 'Incident.CustomFields.c.dep_form_of_address').option(text: 'Dr.').select
browser.text_field(name: 'Incident.CustomFields.c.dep_first_name').set request[:dep_firstName]
browser.text_field(name: 'Incident.CustomFields.c.dep_middle_initial').set request[:dep_middleInitial]
browser.text_field(name: 'Incident.CustomFields.c.dep_last_name').set request[:dep_lastName]
browser.select_list(name: 'Incident.CustomFields.c.dep_suffix_menu').option(text: 'III').select
browser.text_field(name: 'Incident.CustomFields.c.dep_incomingemail').set request[:dep_email]
browser.send_keys :tab
browser.text_field(name: 'Incident.CustomFields.c.dep_incomingemail_Validation').set request[:dep_email]
browser.text_field(name: 'Incident.CustomFields.c.dep_telephone_number').set request[:dep_phoneNumber]
browser.select_list(name: 'Incident.CustomFields.c.dep_country').option(text: 'United States').select
browser.select_list(name: 'Incident.CustomFields.c.dep_state').option(text: 'Illinois').select
browser.text_field(name: 'Incident.CustomFields.c.dep_city').set request[:dep_city]
browser.text_field(name: 'Incident.CustomFields.c.dep_street').set request[:dep_street]
browser.text_field(name: 'Incident.CustomFields.c.dep_zipcode').set request[:dep_zipcode]

# Vet information
browser.select_list(name: 'Incident.CustomFields.c.vet_form_of_address').option(text: 'Dr.').select
browser.text_field(name: 'Incident.CustomFields.c.vet_first_name').set request[:vet_firstName]
browser.text_field(name: 'Incident.CustomFields.c.vet_middle_initial').set request[:vet_middleInitial]
browser.text_field(name: 'Incident.CustomFields.c.vet_last_name').set request[:vet_lastName]
browser.select_list(name: 'Incident.CustomFields.c.vet_suffix_menu').option(text: 'III').select
browser.text_field(name: 'Incident.CustomFields.c.vet_email').set request[:vet_email]
browser.send_keys :tab
browser.text_field(name: 'Incident.CustomFields.c.vet_email_Validation').set request[:vet_email]
browser.text_field(name: 'Incident.CustomFields.c.vet_phone').set request[:vet_phoneNumber]
browser.select_list(name: 'Incident.CustomFields.c.vet_country').option(text: 'United States').select
browser.select_list(name: 'Incident.CustomFields.c.vet_state').option(text: 'Illinois').select
browser.text_field(name: 'Incident.CustomFields.c.vet_city').set request[:vet_city]
browser.text_field(name: 'Incident.CustomFields.c.vet_street').set request[:vet_street]
browser.text_field(name: 'Incident.CustomFields.c.vet_zipcode').set request[:vet_zipcode]

# Veteran Service Information
browser.select_list(name: 'Incident.CustomFields.c.service_branch').option(text: 'Army').select
browser.text_field(name: 'Incident.CustomFields.c.ssn').set request[:ssn]
browser.text_field(name: 'Incident.CustomFields.c.claim_number').set request[:claim_number]
browser.text_field(name: 'Incident.CustomFields.c.service_number').set request[:service_number]
browser.text_field(name: 'Incident.CustomFields.c.date_of_birth').set request[:date_of_birth]
browser.text_field(name: 'Incident.CustomFields.c.e_o_d').set request[:e_o_d]
browser.text_field(name: 'Incident.CustomFields.c.released_from_duty').set request[:released_from_duty]

# Submit the form
browser.button(id: 'rn_FormSubmit_58_Button').click
browser.button(visible_text: 'Finish Submitting Question').click

puts browser.element(tag_name: 'b', visible_text: /#[0-9-]*/).inner_text
