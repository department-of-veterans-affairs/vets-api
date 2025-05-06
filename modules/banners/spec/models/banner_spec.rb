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

  describe '.by_path' do
    let(:path) { '/va-facility-health-care' }
    let(:banner_type) { 'full_width_banner_alert' }

    let!(:matching_banner1) do
      create(:banner,
             entity_bundle: banner_type,
             limit_subpage_inheritance: false,
             context: [
               {
                 entity: {
                   entityUrl: { path: },
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
      create(:banner,
             entity_bundle: banner_type,
             limit_subpage_inheritance: false,
             context: [
               {
                 entity: {
                   entityUrl: { path: '/some-other-path' },
                   fieldOffice: {
                     entity: {
                       entityUrl: { path: }
                     }
                   }
                 }
               }
             ])
    end

    let!(:matching_non_inheriting_banner) do
      create(:banner,
             entity_bundle: banner_type,
             limit_subpage_inheritance: true,
             context: [
               {
                 entity: {
                   entityUrl: { path: },
                   fieldOffice: {
                     entity: {
                       entityUrl: { path: '/some-other-path' }
                     }
                   }
                 }
               }
             ])
    end

    let!(:non_matching_banner) do
      create(:banner,
             entity_bundle: 'different_type',
             context: [
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

    it 'returns banners that match the path type for both direct entityUrls and fieldOffice.entity.entityUrls' do
      result = Banner.by_path(path)

      expect(result).to contain_exactly(matching_banner1, matching_banner2, matching_non_inheriting_banner)
    end

    it 'returns banners that match the path type for subpages, but not if limit_subpage_inheritance?' do
      result = Banner.by_path("#{path}/locations/specific-va-facility")

      expect(result).to contain_exactly(matching_banner1, matching_banner2)
      expect(result).not_to include(matching_non_inheriting_banner)
    end

    it 'does not return banners that do not match the path' do
      result = Banner.by_path(path)

      expect(result).not_to include(non_matching_banner)
    end
  end
end
