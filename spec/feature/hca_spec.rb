require 'features_helper'

RSpec.describe('hca', type: :feature) do
  it 'anonymous application', js: true do
    visit("#{DEFAULT_HOST}/health-care/apply/application/introduction")
    wait_for_new_url('.schemaform-start-button')
    # user details page
    find('#root_firstName').set('first')
    find('#root_lastName').set('last')
    find('#root_dobMonth').find(:option, 'Jan').select_option
    find('#root_dobDay').find(:option, '1').select_option
    find('#root_dobYear').set('1950')
    find('#root_ssn').set('111-22-3333')
    wait_for_new_url('.usa-button')
    # veteran information
    sleep(1)
    wait_for_new_url('.usa-button-primary')
    # dob
    wait_for_new_url('.usa-button-primary')
    # gender
    find('#root_gender').find(:option, 'Male').select_option
    find('#root_maritalStatus').find(:option, 'Never Married').select_option
    wait_for_new_url('.usa-button-primary')
    # addr
    find('#root_veteranAddress_street').set('123 fake st')
    find('#root_veteranAddress_city').set('city')
    find('#root_veteranAddress_state').find(:option, 'Arizona').select_option
    find('#root_veteranAddress_postalCode').set('12345')
    wait_for_new_url('.usa-button-primary')
    # email
    wait_for_new_url('.usa-button-primary')
    # service
    find('#root_lastServiceBranch').find(:option, 'Army').select_option

    %w[Entry Discharge].each do |type|
      find("#root_last#{type}DateMonth option[value='1']").select_option
      find("#root_last#{type}DateDay option[value='1']").select_option
      find("#root_last#{type}DateYear").set(type == 'Entry' ? '1970' : '1971')
    end
    find('#root_dischargeType option[value="honorable"]').select_option
    wait_for_new_url('.usa-button-primary')
    # service special options
    wait_for_new_url('.usa-button-primary')
    # dd214
    wait_for_new_url('.usa-button-primary')
    # compensation
    click('#root_vaCompensationType_3', visible: false)
    wait_for_new_url('.usa-button-primary')
    # financial information
    click('#root_discloseFinancialInformationNo', visible: false)
    wait_for_new_url('.usa-button-primary')
    # insurance
    click('#root_isMedicaidEligibleNo', visible: false)
    click('#root_isEnrolledMedicarePartANo', visible: false)
    wait_for_new_url('.usa-button-primary')
    # other coverage
    click('#root_isCoveredByHealthInsuranceNo', visible: false)
    wait_for_new_url('.usa-button-primary')
    # va facility
    find('#root_view\:preferredFacility_view\:facilityState option[value="AL"]').select_option
    find('#root_view\:preferredFacility_vaMedicalFacility option[value="521GE"]').select_option
    wait_for_new_url('.usa-button-primary')
    # review application
    click('#errorable-checkbox-8', visible: false)
    wait_for_new_url('.usa-button-primary')
    expect(current_path).to eq('/health-care/apply/application/confirmation')
  end
end
