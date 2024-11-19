# frozen_string_literal: true

require 'rails_helper'

Rspec.describe Banner, type: :model do
  # Use FactoryBot to create banners which can be used in all tests.
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

  describe '.by_path_and_type' do
    let(:path) { '/va-facility-health-care' }
    let(:banner_type) { 'full_width_banner_alert' }

    let!(:matching_banner1) do
      create(:banner, entity_bundle: banner_type, context: [
               {
                 entity: {
                   entityUrl: { path: path },
                   fieldOffice: {
                     entity: {
                       entityUrl: { path: '/some-other-path' }
                     }
                   }
                 }
               }
             ])
    end

    let!(:matching_banner2) do
      create(:banner, entity_bundle: banner_type, context: [
               {
                 entity: {
                   entityUrl: { path: '/some-other-path' },
                   fieldOffice: {
                     entity: {
                       entityUrl: { path: path }
                     }
                   }
                 }
               }
             ])
    end

    let!(:non_matching_banner) do
      create(:banner, entity_bundle: 'different_type', context: [
               {
                 entity: {
                   entityUrl: { path: '/some-other-path' },
                   fieldOffice: {
                     entity: {
                       entityUrl: { path: '/another-path' }
                     }
                   }
                 }
               }
             ])
    end

    it 'returns banners that match the path and banner type' do
      result = Banner.by_path_and_type(path, banner_type)

      expect(result).to contain_exactly(matching_banner1, matching_banner2)
    end

    it 'does not return banners that do not match the path or banner type' do
      result = Banner.by_path_and_type(path, banner_type)

      expect(result).not_to include(non_matching_banner)
    end
  end
end
