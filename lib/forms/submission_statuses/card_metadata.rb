# frozen_string_literal: true

module Forms
  module SubmissionStatuses
    module CardMetadata
      DEFAULT_METADATA = {
        form_title: nil,
        presentable_form_id: nil,
        confirmation_days: 30,
        contact_phone: '8008271000',
        contact_hours: '8:00 a.m. to 8:00 p.m. ET'
      }.freeze

      FORM_OVERRIDES = {
        '10-10D' => {
          form_title: 'Application for CHAMPVA benefits',
          presentable_form_id: 'Form 10-10d',
          confirmation_days: 10,
          contact_phone: '8007338387',
          contact_hours: '8:00 a.m. to 7:30 p.m. ET'
        },
        '10-10D-EXTENDED' => {
          form_title: 'Application for CHAMPVA benefits',
          presentable_form_id: 'Form 10-10d',
          confirmation_days: 10,
          contact_phone: '8007338387',
          contact_hours: '8:00 a.m. to 7:30 p.m. ET'
        }
      }.freeze

      class << self
        def for(form_type)
          DEFAULT_METADATA.merge(FORM_OVERRIDES.fetch(form_type.to_s.upcase, {}))
        end
      end
    end
  end
end
