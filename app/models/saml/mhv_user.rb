require 'active_model'

module Saml
  class MhvUser
    extend ActiveModel::Naming
    include ActiveModel::Serialization

    attr_accessor :mhv_icn, # Could be nil, corresponds to the MVI ICN value
                  :mhv_profile, # Non empty hash that includes accountType and availableServices
                  :mhv_uuid, # Non null, the mhv correlation id used for api requests
                  # ID.me required attributes
                  :uuid,
                  :email,
                  :multifactor,
                  :level_of_assurance
  end
end
