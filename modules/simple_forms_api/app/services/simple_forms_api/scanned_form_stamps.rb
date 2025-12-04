# frozen_string_literal: true

module SimpleFormsApi
  class ScannedFormStamps
    # Standard coordinates for upper right corner timestamp (two lines)
    TIMESTAMP_LINE_1_COORDS = [460, 710].freeze
    TIMESTAMP_LINE_2_COORDS = [460, 690].freeze
    TIMESTAMP_FONT_SIZE = 12

    FORMS_WITH_STAMPS = %w[
      21-0779
      21-8940
      21P-530a
      21P-8049
      21-2680
      21-674b
      21-8951-2
      21-0788
      21-4193
      21P-4718a
      21-4140
      21-0304
    ].freeze

    STAMP_PAGE_OVERRIDES = {
      '21-0304' => 1 # Stamp on page 1 (second page) instead of page 0
    }.freeze

    def self.stamps?(form_number)
      FORMS_WITH_STAMPS.include?(form_number)
    end

    def initialize(form_number)
      @form_number = form_number
      @page = STAMP_PAGE_OVERRIDES.fetch(form_number, 0) # Default to page 0
    end

    def desired_stamps
      []
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: TIMESTAMP_LINE_1_COORDS,
          text: 'Application Submitted:',
          page: @page,
          font_size: TIMESTAMP_FONT_SIZE
        },
        {
          coords: TIMESTAMP_LINE_2_COORDS,
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: @page,
          font_size: TIMESTAMP_FONT_SIZE
        }
      ]
    end
  end
end
