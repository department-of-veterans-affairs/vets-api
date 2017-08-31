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
      "branchofservice" => branches_of_service,
    }
  end

  private

  # Mapping from eMIS branch of service keys to value expected by VIC
  SERVICE_KEYS = {
    'F' => 'AF',   # Air Force
    'A' => 'ARMY', # Army
    'C' => 'CG',   # Coast Guard 
    'M' => 'MC',   # Marine Corps
    'N' => 'NAVY', # Navy
    'O' => 'NOAA', # NOAA
    'H' => 'PHS'   # USPHS
  }

  def branches_of_service
    branches = @user.military_information.service_episodes_by_date.map do |ep| 
      SERVICE_KEYS[ep.branch_of_service_code]
    end
    branches.compact.join(',')
  end
end
