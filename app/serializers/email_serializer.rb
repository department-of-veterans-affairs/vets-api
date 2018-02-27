# frozen_string_literal: true

class EmailSerializer < ActiveModel::Serializer
  attribute :email
  attribute :effective_datetime

  def id
    nil
  end

  # Returns the email address nested in the given object
  #
  # @return [String] Email address.  Sample `object.email_address`:
  #   {
  #     "effective_date" => "2018-02-27T14:41:32.283Z",
  #     "value" => "test2@test1.net"
  #   }
  #
  def email
    object&.email_address&.dig 'value'
  end

  # Returns the email's effective datetime nested in the given object
  #
  # @return [String] Effective datetime in the yyyy-MM-dd'T'HH:mm:ss format.
  #   Sample `object.email_address`:
  #     {
  #       "effective_date" => "2018-02-27T14:41:32.283Z",
  #       "value" => "test2@test1.net"
  #     }
  #
  def effective_datetime
    object&.email_address&.dig 'effective_date'
  end
end
