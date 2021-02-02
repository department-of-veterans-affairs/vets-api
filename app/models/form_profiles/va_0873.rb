# frozen_string_literal: true

module VA0873
  FORM_ID = '0873'

  class ServiceDateRange
    include Virtus.model

    attribute :from, String
    attribute :to, String

    def self.permitted_params
      %i[from to]
    end
  end

  class VeteranServiceInformation
    include Virtus.model

    attribute :dateOfBirth, String
    attribute :socialSecurityNumber, String
    attribute :branchOfService, String
    attribute :serviceDateRange, ServiceDateRange
  end
end

class FormProfiles::VA0873 < FormProfile
  class FormAddress
    include Virtus.model

    attribute :fullName, String
    attribute :veteranServiceInformation, VA0873::VeteranServiceInformation
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/topic'
    }
  end
end
