# frozen_string_literal: true

module SimpleFormsApi
  class VBA21526EZ < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_0526'

    # To be added when form is autofilled
    def metadata
      {}
    end

    def desired_stamps
      []
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        date_box_stamp(716, 'Submitted Via: Accredited'),
        date_box_stamp(704, 'Representative Portal on VA.gov'),
        date_box_stamp(692, "#{timestamp.utc.strftime('%I:%M %p')} UTC #{timestamp.utc.strftime('%Y-%m-%d')}"),
        date_box_stamp(680, 'Signee signed with an'),
        date_box_stamp(668, 'identity-verified account.')
      ]
    end

    def date_box_stamp(y_coordinate, text)
      {
        coords: [460, y_coordinate],
        text:,
        page: 8,
        font_size: 8
      }
    end
  end
end
