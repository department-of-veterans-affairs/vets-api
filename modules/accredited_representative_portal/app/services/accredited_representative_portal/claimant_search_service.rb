# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantSearchService
    class Error < RuntimeError; end

    attr_reader :first_name, :last_name, :birth_date, :ssn

    def initialize(first_name, last_name, birth_date, ssn)
      @first_name = first_name.presence
      @last_name = last_name.presence
      @birth_date = birth_date.presence
      @ssn = ssn.presence&.gsub(/-/, '')
    end

    def call
      raise Error, 'First name, last name, DOB and SSN required' unless all_fields_present?

      mpi_service.find_profile_by_attributes(
        first_name:, last_name:, birth_date:, ssn:
      )
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
