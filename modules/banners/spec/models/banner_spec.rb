# frozen_string_literal: true

require 'rails_helper'

Rspec.describe Banner, type: :model do
  # Use FactoryBot to create banner which can be used in all test.
  let(:banner) { create(:banner) }

  # Test that the model is valid with all required attributes.
  it 'is valid with valid attributes' do
    expect(banner).to be_valid
  end

  # Test presence validations for non-boolean fields.
  it 'is not valid without an entity_id' do
    new_banner = Banner.new(entity_bundle: 'homepage', headline: 'Alert!')
    expect(new_banner).not_to be_valid
    expect(new_banner.errors[:entity_id]).to include("can't be blank")
  end

  # Test the model is valid only with a headline.
  it 'is not valid without a headline' do
    new_banner = Banner.new(entity_id: 1, entity_bundle: 'homepage')
    expect(new_banner).not_to be_valid
    expect(new_banner.errors[:headline]).to include("can't be blank")
  end
end
