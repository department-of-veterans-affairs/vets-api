# frozen_string_literal: true

class IdCardAttributes
  attr_accessor :user

  def self.for_user(user)
    id_attributes = IdCardAttributes.new
    id_attributes.user = user
    id_attributes
  end

  # Return dict of traits in canonical order
  def traits
    {
      'edipi' => @user.edipi,
      'firstname' => @user.first_name,
      'lastname' => @user.last_name,
      'address' => @user.address[:street] || '',
      'city' => @user.address[:city] || '',
      'state' => @user.address[:state] || '',
      'zip' => @user.address[:postal_code] || '',
      'email' => @user.email || '',
      'phone' => @user.home_phone || '',
      'title38status' => title38_status_code,
      'branchofservice' => branches_of_service,
      'dischargetype' => discharge_types
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
  }.freeze

  def title38_status_code
    @user.veteran_status.title38_status || 'UNKNOWN'
  rescue
    'UNKNOWN'
  end

  def branches_of_service
    branches = if Flipper.enabled?(:military_information_vaprofile)
                 military_info.service_episodes_by_date.map do |ep|
                   SERVICE_KEYS[ep.branch_of_service_code]
                 end
               else
                 @user.military_information.service_episodes_by_date.map do |ep|
                   SERVICE_KEYS[ep.branch_of_service_code]
                 end
               end
    branches.compact.join(',')
  end

  def discharge_types
    discharges = if Settings.vsp_environment == 'production' || !Flipper.enabled?(:military_information_vaprofile)
                   @user.military_information
                        .service_episodes_by_date
                        .map(&:discharge_character_of_service_code)
                 elsif Flipper.enabled?(:military_information_vaprofile)
                   military_info
                     .service_episodes_by_date
                     .map(&:character_of_discharge_code)
                 end
    discharges.compact.join(',')
  end

  def military_info
    @military_info ||= VAProfile::Prefill::MilitaryInformation.new(user)
  end
end
