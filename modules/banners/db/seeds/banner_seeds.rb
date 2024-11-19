# frozen_string_literal: true

# Create sample Banner records
puts 'Creating sample banners...'

Banner.create!(
  entity_id: 1,
  entity_bundle: 'full_width_banner_alert',
  headline: 'Important Update',
  alert_type: 'warning',
  show_close: true,
  content: 'Please be aware of system maintenance scheduled for tomorrow.',
  context:
  [
    {
      entity: {
        title: 'Operating status | VA Facility health care',
        entityUrl: {
          path: '/va-facility-health-care/operating-status'
        },
        fieldOffice: {
          entity: {
            fieldVamcEhrSystem: 'vista',
            title: 'VA Facility health care',
            entityUrl: {
              path: '/va-facility-health-care'
            }
          }
        }
      }
    },
    {
      entity: {
        title: 'Operating status | VAMC health care',
        entityUrl: {
          path: '/vamc-health-care/operating-status'
        },
        fieldOffice: {
          entity: {
            fieldVamcEhrSystem: 'vista',
            title: 'VAMC health care',
            entityUrl: {
              path: '/vamc-health-care'
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

puts 'Sample banners created!'
