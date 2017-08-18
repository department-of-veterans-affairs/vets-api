# frozen_string_literal: true
class IdCardAttributes

  attr_accessor :user

  def self.for_user(user)
    id_attributes = IdCardAttributes.new
    id_attributes.user = user
    id_attributes
  end

  ## Return dict of traits in canonical order
  def traits
    {
      "edipi" => @user.edipi,
      "firstname" => @user.first_name,
      "lastname" => @user.last_name,
      "address" => @user.va_profile&.address&.street || "",
      "city" => @user.va_profile&.address&.city || "",
      "state" => @user.va_profile&.address&.state || "",
      "zip" => @user.va_profile&.address&.postal_code || "",
      "email" => @user.email,
      "phone" => @user.va_profile&.home_phone || "",
      "branchofservice" => "",
    }
  end
end
