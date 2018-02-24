# frozen_string_literal: true

class EmailSerializer < ActiveModel::Serializer
  attribute :email

  def id
    nil
  end

  # Returns the email address nested in the given object
  #
  # @return [String] Email address.  Sample `object.email_address`:
  #   {
  #     "effective_date" => "2012-04-03T04:00:00.000+0000",
  #     "value" => "test2@test1.net"
  #   }
  #
  def email
    object&.email_address.dig 'value'
  end
end
