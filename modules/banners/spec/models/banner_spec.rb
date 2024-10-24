# frozen_string_literal: true

require 'rails_helper'

Rspec.describe Banner, type: :model do
  # Test that the model is valid with all required attributes.
  it 'is valid with valid attributes' do
    banner = Banner.new(
      entity_id: 1,
      entity_bundle: 'homepage',
      headline: 'Important Alert!',
      alert_type: 'warning',
      show_close: true,
      content: 'This is a warning alert',
      context: [
        {
          entity: {
            title: 'Operating status | VA Puget Sound health care',
            entityUrl: {
              path: '/puget-sound-health-care/operating-status'
            },
            fieldOffice: {
              entity: {
                fieldVamcEhrSystem: 'vista',
                title: 'VA Puget Sound health care',
                entityUrl: {
                  path: '/puget-sound-health-care'
                }
              }
            }
          }
        }
      ],
      operating_status_cta: true,
      email_updates_button: true,
      find_facilities_cta: false,
      limit_subpage_inheritance: false
    )
    expect(banner).to be_valid
  end

  # Test presence validations for non-boolean fields
  it 'is not valid without an entity_id' do
    banner = Banner.new(entity_bundle: 'homepage', headline: 'Alert!')
    expect(banner).not_to be_valid
    expect(banner.errors[:entity_id]).to include("can't be blank")
  end

  it 'is not valid without a headline' do
    banner = Banner.new(entity_id: 1, entity_bundle: 'homepage')
    expect(banner).not_to be_valid
    expect(banner.errors[:headline]).to include("can't be blank")
  end

  # Test uniqueness of entity_id
  it 'is not valid if the entity_id is not unique' do
    Banner.create(
      entity_id: 1,
      entity_bundle: 'homepage',
      headline: 'Original Alert',
      alert_type: 'info'
    )

    duplicate_banner = Banner.new(
      entity_id: 1,
      entity_bundle: 'homepage',
      headline: 'Duplicate Alert'
    )
    expect(duplicate_banner).not_to be_valid
    expect(duplicate_banner.errors[:entity_id]).to include('has already been taken')
  end
end
