# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneySerializer < ActiveModel::Serializer
    attributes :status, :date_request_accepted, :representative, :previous_poa

    # "Uploaded" is an internal-only status indicating that the POA PDF
    # was uploaded to VBMS, but we did not make it to updating BGS.
    # For external consistency, return as "Updated"
    def status
      if object[:status] == ClaimsApi::PowerOfAttorney::UPLOADED
        ClaimsApi::PowerOfAttorney::UPDATED
      else
        object[:status]
      end
    end
  end
end
