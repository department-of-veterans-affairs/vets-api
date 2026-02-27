# frozen_string_literal: true

module HasStructuredData
  extend ActiveSupport::Concern

  # Normalize a name hash into first, middle/initial, and last strings.
  #
  # @param name_hash [Hash, nil]
  # @return [Hash]
  def build_name(name_hash)
    first = name_hash&.fetch('first', nil)
    middle = name_hash&.fetch('middle', nil)
    last = name_hash&.fetch('last', nil)
    suffix = name_hash&.fetch('suffix', nil)

    {
      first:,
      last:,
      middle:,
      middle_initial: middle&.slice(0, 1),
      suffix:,
      full: [first, middle, last, suffix].compact.join(' ').presence
    }
  end

  # Flatten an address hash into a single-line string.
  #
  # @param address [Hash, nil]
  # @return [String, nil]
  def build_address_block(address)
    return unless address

    street_line = [address['street'], address['street2']].compact.join(' ').strip
    city_line = [address['city'], address['state'], address['postalCode']].compact.join(' ').strip
    lines = [street_line, city_line, address['country']].compact_blank
    lines.join(' ').presence
  end

  # Build the claimant address block, falling back to veteran address when needed.
  #
  # @param form [Hash]
  # @return [String, nil]
  def claimant_address_block(form)
    address = form['claimantAddress'] || fallback_claimant_address(form)
    build_address_block(address)
  end

  # Provide a fallback claimant address using the veteran address data.
  #
  # @param form [Hash]
  # @return [Hash, nil]
  def fallback_claimant_address(form)
    veteran_address = form['veteranAddress']
    return unless veteran_address

    {
      'street' => veteran_address['street'],
      'street2' => veteran_address['street2'],
      'city' => veteran_address['city'],
      'state' => veteran_address['state'],
      'postalCode' => veteran_address['postalCode'],
      'country' => veteran_address['country']
    }
  end

  # Return the claimant phone number when the country is US.
  #
  # @param form [Hash]
  # @return [String, nil]
  def claimant_phone_number(form)
    primary_phone = form['primaryPhone'] || {}
    number = format_phone(primary_phone['contact'])
    return if number.blank?

    primary_phone['countryCode']&.casecmp?('US') ? number : nil
  end

  # Determine the international phone number field from either explicit internationalPhone or non-US contact.
  #
  # @param form [Hash]
  # @param primary_phone [Hash]
  # @return [String, nil]
  def international_phone_number(form, primary_phone, international_key = 'internationalPhone')
    return format_phone(form[international_key]) if form[international_key].present?
    return format_phone(primary_phone['contact']) unless primary_phone['countryCode']&.casecmp?('US')

    nil
  end

  # Strip a phone string down to digits.
  #
  # @param value [String, nil]
  # @return [String, nil]
  def format_phone(value)
    sanitize_phone(value)
  end

  # Format the signature date for IBM consumption.
  #
  # @param form [Hash]
  # @return [String, nil]
  def claim_date_signed(form)
    format_date(form['dateSigned'] || form['signatureDate'])
  end

  # Strip all non-digit characters from a phone string.
  #
  # @param phone [String, nil]
  # @return [String, nil]
  def sanitize_phone(phone)
    return unless phone

    phone.to_s.gsub(/\D/, '')
  end

  # Determine if the IAM payload should use VA received date.
  #
  # @param form [Hash]
  # @return [Boolean]
  def use_va_rcvd_date?(form)
    form['firstTimeReporting'].presence || false
  end

  # Define placeholders for the witness fields in the IBM payload.
  #
  # @return [Hash]
  def build_witness_fields
    %w[WITNESS_1_NAME WITNESS_1_SIGNATURE WITNESS_1_ADDRESS WITNESS_2_NAME WITNESS_2_ADDRESS WITNESS_2_SIGNATURE]
      .index_with(nil)
  end

  # Format a numeric amount for IBM (commas + two decimals).
  #
  # @param value [String, Numeric]
  # @return [String, nil]
  def format_currency(value)
    return unless value

    number = BigDecimal(value.to_s.gsub(/[^\d.-]/, ''))
    parts = format('%.2f', number).split('.')
    "$#{parts[0].reverse.scan(/\d{1,3}/).join(',').reverse}.#{parts[1]}"
  rescue ArgumentError
    nil
  end

  # Build a set of IBM fields for a currency amount, breaking it into full, thousands, hundreds, and cents.
  #
  # @param amount [Numeric, nil]
  # @param keys [Hash] A hash with keys :full, :thousands, :hundreds, and :cents mapping to the corresponding IBM fields
  # @return [Hash]
  def build_currency_fields(amount, keys)
    {
      keys[:full] => format_currency(amount || 0),
      keys[:thousands] => amount ? (amount / 1000).floor : 0,
      keys[:hundreds] => amount ? (amount.floor % 1000) : 0,
      keys[:cents] => amount ? ((amount * 100).to_i % 100) : 0
    }
  end

  # Normalize a date to MM/DD/YYYY for IBM.
  #
  # @param value [String, Date]
  # @return [String, nil]
  def format_date(value)
    return unless value

    parsed = Date.parse(value.to_s)
    parsed.strftime('%m/%d/%Y')
  rescue ArgumentError
    nil
  end

  # Normalize city, (state/country) for IBM.
  #
  # @param place [Hash]
  # @return [String, nil]
  def format_place(place)
    return unless place

    [place['city'], place['state'] || place['otherCountry']].compact.join(', ')
  end

  ##
  # Build a yes/no pair of fields for IBM based on a boolean value.
  #
  # @param field [Boolean, nil]
  # @param yes [String] The IBM field name to use for the "yes" value.
  # @param no [String] The IBM field name to use for the "no" value.
  # @return [Hash] A hash with the yes and no field names as keys, and boolean values indicating which one is true.
  def y_n_pair(field, yes, no)
    return {} if field.nil?

    {
      yes => field == true,
      no => field == false
    }
  end
end
