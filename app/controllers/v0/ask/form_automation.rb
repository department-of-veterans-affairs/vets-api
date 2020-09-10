require 'watir'
require 'selenium-webdriver'
require 'webdrivers'

browser = Watir::Browser.new
browser.goto 'https://iris--tst.custhelp.com/app/ask'

def select_topic(browser, topic_labels)
  topic_labels.each do |label|
    browser.link(visible_text: label).click
  end
end

browser.button(id: 'rn_ProductCategoryInput_3_Product_Button').click
select_topic(browser, ['E-Benefits Portal', 'About eBenefits'])
browser.button(id: 'rn_ProductCategoryInput_3_Product_ConfirmButton').click

sleep(10)

# browser.select_list(name: 'Incident.CustomFields.c.route_to_state').option(text: 'ALABAMA').select

browser.button(id: 'rn_ProductCategoryInput_6_Category_Button').click
query = 'Array.from(document.getElementsByClassName("ygtvlabel")).filter((element) => element.innerHTML === "Question")[0].click();'
browser.execute_script(query)
browser.button(id: 'rn_ProductCategoryInput_6_Category_ConfirmButton').click

browser.textarea(name: 'Incident.Threads').set 'This is our test question'

browser.select_list(name: 'Incident.CustomFields.c.vet_status').option(text: 'a General Question (Vet Info Not Needed)').select

browser.select_list(name: 'Incident.CustomFields.c.form_of_address').option(text: 'Dr.').select
browser.text_field(name: 'Incident.CustomFields.c.first_name').set 'Jane'
browser.text_field(name: 'Incident.CustomFields.c.last_name').set 'Doe'
browser.text_field(name: 'Incident.CustomFields.c.incomingemail').set 'janedoe@va.gov'
browser.send_keys :tab
browser.text_field(name: 'Incident.CustomFields.c.incomingemail_Validation').set 'janedoe@va.gov'
browser.select_list(name: 'Incident.CustomFields.c.country').option(text: 'United States').select
browser.select_list(name: 'Incident.CustomFields.c.state').option(text: 'Illinois').select
browser.text_field(name: 'Incident.CustomFields.c.zipcode').set '60601'

browser.button(id: 'rn_FormSubmit_58_Button').click
browser.button(visible_text: 'Finish Submitting Question').click

puts browser.element(tag_name: 'b', visible_text: /#[0-9-]*/).inner_text

sleep(5)


