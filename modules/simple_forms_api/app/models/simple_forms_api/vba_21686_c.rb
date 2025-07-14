# frozen_string_literal: true

module SimpleFormsApi
  class VBA21686C < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_0686'

    # To be added when form is autofilled
    def metadata
      {}
    end

    def desired_stamps
      []
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        date_box_stamp(710, 'Submitted Via: Accredited Representative'),
        date_box_stamp(695, 'Portal on VA.gov'),
        date_box_stamp(680, "#{timestamp.utc.strftime('%I:%M %p')} UTC #{timestamp.utc.strftime('%Y-%m-%d')}"),
        date_box_stamp(665, 'Signee signed with an identity-verified'),
        date_box_stamp(650, 'account.')
      ]
    end

    def date_box_stamp(y_coordinate, text)
      {
        coords: [395, y_coordinate],
        text:,
        page: 0,
        font_size: 10
      }
    end
  end
end
