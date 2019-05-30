require 'features_helper'

RSpec.describe('hca', type: :feature) do
  it 'foo', js: true do
    visit('http://localhost:3001/health-care/apply/application/introduction')
    wait_for_new_url('.schemaform-start-button')
    # user details page
    find('#root_firstName').set('first')
    find('#root_lastName').set('last')
    find('#root_dobMonth').find(:option, 'Jan').select_option
    find('#root_dobDay').find(:option, '1').select_option
    find('#root_dobYear').set('1950')
    find('#root_ssn').set('111-22-3333')
    binding.pry; fail
    wait_for_new_url('.usa-button')
    binding.pry; fail
  end
end
