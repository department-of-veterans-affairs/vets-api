# frozen_string_literal: true

module SimpleFormsApi
  class VBA21p0537 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21p_0537'

    def words_to_remove
      veteran_ssn + recipient_phone + recipient_email + spouse_ssn + spouse_date_of_birth +
        remarriage_dates + in_reply_refer_to
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_file_number').presence || format_ssn_for_file_number,
        'zipCode' => '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('recipient', 'full_name', 'first')
    end

    def notification_email_address
      data.dig('recipient', 'email')
    end

    def zip_code_is_us_based
      true
    end

    def submission_date_stamps(_timestamp = Time.current)
      []
    end

    def desired_stamps
      stamp_items = [
        { coords: [500, 645], text: data['in_reply_refer_to'], page: 0, font_size: 9 },
        { coords: [50, 245], text: data.dig('recipient', 'signature'), page: 2 }
      ]

      # If email address is longer than what fits in the form, just stamp
      # it at the bottom of the page.
      if notification_email_address&.length&.> 30
        stamp_items.push({ coords: [30, 100], text: 'Email overflow:', page: 1, font_size: 9 })
        stamp_items.push({ coords: [30, 75], text: notification_email_address, page: 1, font_size: 9 })
      end

      stamp_items
    end

    def track_user_identity(confirmation_number)
      identity = @data['has_remarried'] ? 'remarried' : 'not_remarried'
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21P-0537 submission user identity', identity:, confirmation_number:)

      if @data['has_remarried'] && @data.dig('remarriage', 'has_terminated')
        termination_status = 'terminated'
        StatsD.increment("#{STATS_KEY}.#{termination_status}")
        Rails.logger.info('Simple forms api - 21P-0537 remarriage status', termination_status:, confirmation_number:)
      end
    end

    private

    def format_ssn_for_file_number
      ssn_parts = @data.dig('veteran', 'ssn')
      return '' unless ssn_parts

      "#{ssn_parts['first3']}#{ssn_parts['middle2']}#{ssn_parts['last4']}"
    end

    def veteran_ssn
      ssn_parts = data.dig('veteran', 'ssn')
      return [] unless ssn_parts

      [
        ssn_parts['first3'],
        ssn_parts['middle2'],
        ssn_parts['last4']
      ]
    end

    def recipient_phone
      phones = []

      # Daytime phone
      daytime_parts = data.dig('recipient', 'phone', 'daytime')
      if daytime_parts
        phones += [
          daytime_parts['area_code'],
          daytime_parts['prefix'],
          daytime_parts['line_number']
        ]
      end

      # Evening phone
      evening_parts = data.dig('recipient', 'phone', 'evening')
      if evening_parts
        phones += [
          evening_parts['area_code'],
          evening_parts['prefix'],
          evening_parts['line_number']
        ]
      end

      phones
    end

    def recipient_email
      email = data.dig('recipient', 'email')
      return [] unless email

      [
        email&.[](0..19),
        email&.[](20..)
      ].compact
    end

    def spouse_ssn
      ssn_parts = data.dig('remarriage', 'spouse_ssn')
      return [] unless ssn_parts

      [
        ssn_parts['first3'],
        ssn_parts['middle2'],
        ssn_parts['last4']
      ]
    end

    def spouse_date_of_birth
      date_parts = data.dig('remarriage', 'spouse_date_of_birth')
      return [] unless date_parts

      [
        date_parts['year'],
        date_parts['month'],
        date_parts['day']
      ]
    end

    def remarriage_dates
      dates = []

      # Marriage date
      marriage_date = data.dig('remarriage', 'date_of_marriage')
      if marriage_date
        dates += [
          marriage_date['year'],
          marriage_date['month'],
          marriage_date['day']
        ]
      end

      # Termination date (if applicable)
      termination_date = data.dig('remarriage', 'termination_date')
      if termination_date && termination_date['year'].present?
        dates += [
          termination_date['year'],
          termination_date['month'],
          termination_date['day']
        ]
      end

      dates
    end

    def in_reply_refer_to
      refer_to = data['in_reply_refer_to']
      return [] unless refer_to

      [
        refer_to&.[](0..4),
        refer_to&.[](5..)
      ].compact
    end
  end
end
