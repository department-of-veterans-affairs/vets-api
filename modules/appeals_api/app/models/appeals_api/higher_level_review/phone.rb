# frozen_string_literal: true

class AppealsApi::HigherLevelReview::Phone
  MAX_LENGTH = 20

  attr_reader :country_code, :area_code, :number, :extension

  def initialize(phone_hash)
    phone_hash ||= {}
    @country_code = phone_hash['countryCode'].presence
    @area_code = phone_hash['areaCode'].presence
    @number = phone_hash['phoneNumber'].presence
    @extension = phone_hash['phoneNumberExt'].presence
  end

  def to_s
    return '' if blank?

    cc = country_code && "+#{country_code} "
    ext = extension && " ext #{extension}"

    "#{cc}#{area_code}#{number}#{ext}"
  end

  def too_long?
    to_s.length > MAX_LENGTH
  end

  def blank?
    [country_code, area_code, number, extension].all? :blank?
  end
end
