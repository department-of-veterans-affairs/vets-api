# frozen_string_literal: true

class PhoneNumberSerializer < ActiveModel::Serializer
  attribute :number
  attribute :extension
  attribute :country_code

  def id
    nil
  end

  # Returns the phone number nested in the given object.
  #
  # @return [String] Phone number.  Sample `object.phone`:
  #   {
  #     "country_code" => "1",
  #     "extension" => "",
  #     "number" => "4445551212"
  #   }
  #
  def number
    object&.phone&.dig 'number'
  end

  # Returns the extension nested in the given object.
  #
  # @return [String] Extension.  Sample `object.phone`:
  #   {
  #     "country_code" => "1",
  #     "extension" => "",
  #     "number" => "4445551212"
  #   }
  #
  def extension
    object&.phone&.dig 'extension'
  end

  # Returns the country code nested in the given object.
  #
  # @return [String] Country code.  Sample `object.phone`:
  #   {
  #     "country_code" => "1",
  #     "extension" => "",
  #     "number" => "4445551212"
  #   }
  #
  def country_code
    object&.phone&.dig 'country_code'
  end
end
