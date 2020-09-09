require 'watir'
require 'selenium-webdriver'
require 'webdrivers'

browser = Watir::Browser.new
browser.goto 'https://iris--tst.custhelp.com/app/ask'

browser.button(id: 'rn_ProductCategoryInput_3_Product_Button').click
# query = 'Array.from(document.getElementsByClassName("ygtvlabel")).filter((element) => element.innerHTML === "Guardianship/Custodianship Issues")[0].click();'
# query = 'return Array.from(document.getElementsByClassName("ygtvlabel")).length;'

# browser.execute_script(query)
# browser.button(id: 'rn_ProductCategoryInput_3_Product_ConfirmButton').click

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

sleep(5)


