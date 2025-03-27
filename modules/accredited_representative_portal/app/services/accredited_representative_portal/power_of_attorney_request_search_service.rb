# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSearchService
    class Error < RuntimeError; end

    attr_reader :poa_requests, :first_name, :last_name, :birth_date, :ssn

    def initialize(poa_requests, first_name, last_name, birth_date, ssn)
      @poa_requests = poa_requests
      @first_name = first_name.presence
      @last_name = last_name.presence
      @birth_date = birth_date.presence
      @ssn = ssn.presence&.gsub(/-/, '')
    end

    def call
      return poa_requests if empty_search_criteria?
      raise Error, 'First name, last name, DOB and SSN required' unless all_fields_present?

      icn = mpi_service.find_profile_by_attributes(
        first_name:, last_name:, birth_date:, ssn:
      ).try(:profile).try(:icn)

      return poa_requests.none if icn.blank?

      poa_requests.joins(:claimant).where(claimant: { icn: })
    end

    def mpi_service
      @mpi_service ||= MPI::Service.new
    end

    def empty_search_criteria?
      [first_name, last_name, birth_date, ssn].all?(&:blank?)
    end

    def all_fields_present?
      [first_name, last_name, birth_date, ssn].all?(&:present?)
    end
  end
end
