require 'active_model'

module Saml
  class DslogonUser
    extend ActiveModel::Naming
    include ActiveModel::Serialization

    attr_accessor :dslogon_uuid,
                  :dslogon_fname,
                  :dslogon_lname,
                  :dslogon_mname,
                  :dslogon_idtype,
                  :dslogon_idvalue,
                  :dslogon_gender,
                  :dslogon_birth_date,
                  :dslogon_deceased,
                  :dslogon_status,
                  :dslogon_assurance,
                  # ID.me required attributes
                  :uuid,
                  :email,
                  :multifactor,
                  :level_of_assurance
  end
end
