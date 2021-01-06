# frozen_string_literal: true

require 'evss/gi_bill_status/service'

module VA10203dny
  FORM_ID = '22-10203DNY'

  class FormInstitutionInfo
    include Virtus.model

    attribute :name, String
    attribute :city, String
    attribute :state, String
    attribute :country, String
  end

  class FormEntitlementInformation
    include Virtus.model

    attribute :months, Integer
    attribute :days, Integer
  end
end

class FormProfiles::VA10203dny < FormProfiles::VA10203
  self.table_name = 'va10203dny'

  attribute :remaining_entitlement, VA10203dny::FormEntitlementInformation
  attribute :school_information, VA10203dny::FormInstitutionInfo
end
