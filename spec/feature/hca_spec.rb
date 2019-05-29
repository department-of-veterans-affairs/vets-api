require 'features_helper'

RSpec.describe('hca', type: :feature) do
  it 'foo', js: true do
    visit('http://localhost:3001/health-care/apply/application/introduction')
    click('.schemaform-start-button')
    binding.pry; fail
  end
end
