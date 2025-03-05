# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSearchService
    class Error < RuntimeError; end

    attr_reader :poa_requests, :first_name, :last_name, :dob, :ssn

    def initialize(poa_requests, first_name, last_name, dob, ssn)
      @poa_requests = poa_requests
      @first_name = first_name.presence
      @last_name = last_name.presence
      @dob = dob.presence
      @ssn = ssn.presence&.gsub(/-/, '')
    end

    def call
      return poa_requests if empty_search_criteria?
      raise Error, 'First name, last name, DOB and SSN required' unless all_fields_present?

      ids = poa_requests.select do |poa_request|
        form = poa_request.power_of_attorney_form

        form&.veteran_first_name&.downcase&.match?(first_name.downcase) &&
          form&.veteran_last_name&.downcase&.match?(last_name.downcase) &&
          form&.veteran_ssn&.match?(ssn) &&
          form&.veteran_dob&.match?(dob)
      end.pluck(:id)
      poa_requests.where(id: ids)
    end

    def empty_search_criteria?
      [first_name, last_name, dob, ssn].all?(&:blank?)
    end

    def all_fields_present?
      [first_name, last_name, dob, ssn].all?(&:present?)
    end
  end
end
