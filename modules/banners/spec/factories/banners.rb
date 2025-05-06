# frozen_string_literal: true

FactoryBot.define do
  factory :banner do
    sequence(:entity_id) { |n| n }
    entity_bundle { 'full_width_banner_alert' }
    headline { 'Important Alert!' }
    alert_type { 'warning' }
    show_close { false }
    content { '<p>This is a warning alert.</p>' }
    # rubocop:disable RSpec/MissingExampleGroupArgument
    context {
      [
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
      ]
    }
    # rubocop:enable RSpec/MissingExampleGroupArgument

    operating_status_cta { false }
    email_updates_button { false }
    find_facilities_cta { false }
    limit_subpage_inheritance { false }
  end
end
