# frozen_string_literal: true

##
# This error is being used to convey that the user's patient FHIR record likely has not yet been created.
#
module MedicalRecords
  class PatientNotFound < StandardError
  end
end
