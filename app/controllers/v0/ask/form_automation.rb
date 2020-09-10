require 'watir'
require 'selenium-webdriver'
require 'webdrivers'

browser = Watir::Browser.new
browser.goto 'https://iris--tst.custhelp.com/app/ask'

def select_topic(browser, topic_labels)
  browser.button(id: 'rn_ProductCategoryInput_3_Product_Button').click
  topic_labels.each do |label|
    browser.link(visible_text: label).click
  end
  browser.button(id: 'rn_ProductCategoryInput_3_Product_ConfirmButton').click
end

select_topic(browser, ['Compensation (Service-Connected Bens)', 'Filing for compensation benefits'])
browser.select_list(name: 'Incident.CustomFields.c.route_to_state').option(text: 'ALABAMA').select

browser.button(id: 'rn_ProductCategoryInput_6_Category_Button').click
query = 'Array.from(document.getElementsByClassName("ygtvlabel")).filter((element) => element.innerHTML === "Question")[0].click();'
browser.execute_script(query)
browser.button(id: 'rn_ProductCategoryInput_6_Category_ConfirmButton').click

browser.textarea(name: 'Incident.Threads').set 'This is our test question'

browser.select_list(name: 'Incident.CustomFields.c.vet_status').option(text: 'for the Dependent of a Veteran').select
browser.radio(id: 'rn_SelectionInput_9_Incident.CustomFields.c.inquirer_is_dependent_0').label.click
browser.select_list(name: 'Incident.CustomFields.c.relation_to_vet').option(text: 'Other').select
browser.radio(id: 'rn_SelectionInput_11_Incident.CustomFields.c.vet_dead_0').label.click

# Your Contact Information
browser.select_list(name: 'Incident.CustomFields.c.form_of_address').option(text: 'Dr.').select
browser.text_field(name: 'Incident.CustomFields.c.first_name').set 'jane'
browser.text_field(name: 'Incident.CustomFields.c.middle_initial').set 'X'
browser.text_field(name: 'Incident.CustomFields.c.last_name').set 'doe'
browser.select_list(name: 'Incident.CustomFields.c.suffix_menu').option(text: 'III').select
browser.text_field(name: 'Incident.CustomFields.c.incomingemail').set 'janedoe@va.gov'
browser.send_keys :tab
browser.text_field(name: 'Incident.CustomFields.c.incomingemail_Validation').set 'janedoe@va.gov'
browser.text_field(name: 'Incident.CustomFields.c.telephone_number').set '0001112222'
browser.select_list(name: 'Incident.CustomFields.c.country').option(text: 'United States').select
browser.select_list(name: 'Incident.CustomFields.c.state').option(text: 'Illinois').select
browser.text_field(name: 'Incident.CustomFields.c.city').set 'Edgebrook'
browser.text_field(name: 'Incident.CustomFields.c.street').set '100 Oak Dr'
browser.text_field(name: 'Incident.CustomFields.c.zipcode').set '60601'

# Dependent Information
browser.select_list(name: 'Incident.CustomFields.c.dep_relation_to_vet').option(text: 'Other').select
browser.select_list(name: 'Incident.CustomFields.c.dep_form_of_address').option(text: 'Dr.').select
browser.text_field(name: 'Incident.CustomFields.c.dep_first_name').set 'jim'
browser.text_field(name: 'Incident.CustomFields.c.dep_middle_initial').set 'X'
browser.text_field(name: 'Incident.CustomFields.c.dep_last_name').set 'doe'
browser.select_list(name: 'Incident.CustomFields.c.dep_suffix_menu').option(text: 'III').select
browser.text_field(name: 'Incident.CustomFields.c.dep_incomingemail').set 'jimdoe@va.gov'
browser.send_keys :tab
browser.text_field(name: 'Incident.CustomFields.c.dep_incomingemail_Validation').set 'jimdoe@va.gov'
browser.text_field(name: 'Incident.CustomFields.c.dep_telephone_number').set '0001112222'
browser.select_list(name: 'Incident.CustomFields.c.dep_country').option(text: 'United States').select
browser.select_list(name: 'Incident.CustomFields.c.dep_state').option(text: 'Illinois').select
browser.text_field(name: 'Incident.CustomFields.c.dep_city').set 'Edgebrook'
browser.text_field(name: 'Incident.CustomFields.c.dep_street').set '100 Oak Dr'
browser.text_field(name: 'Incident.CustomFields.c.dep_zipcode').set '60601'

# Vet information
browser.select_list(name: 'Incident.CustomFields.c.vet_form_of_address').option(text: 'Dr.').select
browser.text_field(name: 'Incident.CustomFields.c.vet_first_name').set 'sammy'
browser.text_field(name: 'Incident.CustomFields.c.vet_middle_initial').set 'X'
browser.text_field(name: 'Incident.CustomFields.c.vet_last_name').set 'doe'
browser.select_list(name: 'Incident.CustomFields.c.vet_suffix_menu').option(text: 'III').select
browser.text_field(name: 'Incident.CustomFields.c.vet_email').set 'sammydoe@va.gov'
browser.send_keys :tab
browser.text_field(name: 'Incident.CustomFields.c.vet_email_Validation').set 'sammydoe@va.gov'
browser.text_field(name: 'Incident.CustomFields.c.vet_phone').set '0001112222'
browser.select_list(name: 'Incident.CustomFields.c.vet_country').option(text: 'United States').select
browser.select_list(name: 'Incident.CustomFields.c.vet_state').option(text: 'Illinois').select
browser.text_field(name: 'Incident.CustomFields.c.vet_city').set 'Edgebrook'
browser.text_field(name: 'Incident.CustomFields.c.vet_street').set '100 Oak Dr'
browser.text_field(name: 'Incident.CustomFields.c.vet_zipcode').set '60601'

# Veteran Service Information
browser.select_list(name: 'Incident.CustomFields.c.service_branch').option(text: 'Army').select
browser.text_field(name: 'Incident.CustomFields.c.ssn').set '111223333'
browser.text_field(name: 'Incident.CustomFields.c.claim_number').set '1234567'
browser.text_field(name: 'Incident.CustomFields.c.service_number').set '123456789012'
browser.text_field(name: 'Incident.CustomFields.c.date_of_birth').set '01-01-1970'
browser.text_field(name: 'Incident.CustomFields.c.e_o_d').set '01-01-2003'
browser.text_field(name: 'Incident.CustomFields.c.released_from_duty').set '01-01-2009'

browser.button(id: 'rn_FormSubmit_58_Button').click
browser.button(visible_text: 'Finish Submitting Question').click

puts browser.element(tag_name: 'b', visible_text: /#[0-9-]*/).inner_text

sleep(7)


