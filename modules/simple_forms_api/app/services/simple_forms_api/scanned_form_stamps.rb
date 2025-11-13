# frozen_string_literal: true

module SimpleFormsApi
  class ScannedFormStamps
    STAMP_CONFIGS = {
      '21-0779' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: 'Application Submitted:',
              page: 0,
              font_size: 12
            },
            {
              coords: [460, 690],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-8940' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21P-530a' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21P-8049' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-2680' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-674b' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-8951-2' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-0788' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-4193' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21P-4718a' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-4140' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 0,
              font_size: 12
            }
          ]
        }
      },
      '21-0304' => {
        submission_date_stamps: lambda { |timestamp|
          [
            {
              coords: [460, 710],
              text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
              page: 1, # Second page (0-indexed)
              font_size: 12
            }
          ]
        }
      }
    }.freeze

    def initialize(form_number)
      @form_number = form_number
      @config = STAMP_CONFIGS[form_number]
    end

    def desired_stamps
      []
    end

    def submission_date_stamps(timestamp = Time.current)
      @config ? @config[:submission_date_stamps].call(timestamp) : []
    end

    def self.stamps?(form_number)
      STAMP_CONFIGS.key?(form_number)
    end
  end
end
