FactoryBot.define do
  factory :banner do
    entity_id { 1234 }
    entity_bundle { 'full_width_banner_alert' }
    headline { 'Hurricane season is upon us.' }
    alert_type { 'info' }
    show_close { false }
    content { '<p>Prepare for this coming hurricane season.</p>' }
    context {
      '{[
        {
          "entity": {
            "title": "Operating status | VA San Francisco health care",
            "entityUrl": {
              "path": "/san-francisco-health-care/operating-status"
            },
            "fieldOffice": {
              "entity": {
                "fieldVamcEhrSystem": "vista",
                "title": "VA San Francisco health care",
                "entityUrl": {
                  "path": "/san-francisco-health-care"
                }
              }
            }
          }
        }
      ]}'
    }

    operating_status_cta { false }
    email_updates_button { false }
    find_facilities_cta { false }
    limit_subpage_inheritance { false }
  end
end
