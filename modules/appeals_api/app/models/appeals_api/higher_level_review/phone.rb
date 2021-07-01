# frozen_string_literal: true

class AppealsApi::HigherLevelReview::Phone
  MAX_LENGTH = 20

  def initialize(phone_hash)
    phone_hash = (phone_hash || {}).symbolize_keys
    @country_code = phone_hash[:countryCode].presence&.strip
    @area_code = phone_hash[:areaCode].presence&.strip
    @phone_number = phone_hash[:phoneNumber].presence&.strip
    @phone_number_ext = phone_hash[:phoneNumberExt].presence&.strip
  end

  def to_s
    return '' if blank?

    number = country_string + number_string
    ext = ext_string(MAX_LENGTH - number.length)

    number + ext
  end

  def too_long?
    to_s.length > MAX_LENGTH
  end

  def too_long_error_message
    "Phone number will not fit on form (#{MAX_LENGTH} char limit): #{self}" if too_long?
  end

  attr_reader :country_code, :area_code, :phone_number, :phone_number_ext

  private

  def blank?
    [country_code, area_code, phone_number, phone_number_ext].all? :blank?
  end

  def country_string
    return '' if !country_code || country_code.to_s == '1'

    "+#{country_code}-"
  end

  def number_string
    full_number = "#{area_code}#{phone_number}"

    return full_number unless full_number.length == 10

    [
      full_number.slice(0, 3),
      full_number.slice(3, 3),
      full_number.slice(6, 4)
    ].join('-')
  end

  # tries to make a extension string that is <= max_length
  def ext_string(max_length)
    return '' unless phone_number_ext

    max_prefix_length = max_length - phone_number_ext.length

    [' ext ', ' ext', ' ex', ' x'].find(-> { 'x' }) do |prefix|
      prefix.length <= max_prefix_length
    end + phone_number_ext
  end
end
