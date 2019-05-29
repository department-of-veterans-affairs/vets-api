require 'features_helper'

RSpec.describe('hca', type: :feature) do
  it 'foo', js: true do
    visit('/')
    binding.pry; fail
  end
end
