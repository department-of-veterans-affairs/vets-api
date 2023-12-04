# frozen_string_literal: true

require 'common/exceptions/service_error'

##
# This error is being used to convey that the user's patient FHIR record likely has not yet been created.
#
module MedicalRecords
  class PatientNotFound < ServiceError
  end
end
