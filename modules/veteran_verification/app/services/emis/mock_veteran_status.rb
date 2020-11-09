# frozen_string_literal: true

require 'emis/veteran_status_service'

module EMISRedis
  # EMIS veteran status service redis cached model.
  # Much of this class depends on the Title 38 Status codes, which are:
  #
  # V1 = Title 38 Veteran
  # V2 = VA Beneficiary
  # V3 = Military Person, not Title 38 Veteran, NOT DoD-Affiliated
  # V4 = Non-military person
  # V5 = EDI PI Not Found in VADIR (service response only not stored in table)
  # V6 = Military Person, not Title 38 Veteran, DoD-Affiliated
  #
  # @see https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/SiP-Prefill/Prefill/eMIS_Integration/eMIS_Documents/MIS%20Service%20Description%20Document.docx
  #
  class MockVeteranStatus < VeteranStatus
    def service
      @service ||= EMIS::MockVeteranStatusService.new
    end
  end
end
