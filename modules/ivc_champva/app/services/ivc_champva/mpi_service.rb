# frozen_string_literal: true

require 'mpi/service'

module IvcChampva
  class MpiService
    def initialize
      @mpi_service = MPI::Service.new
      @monitor = IvcChampva::Monitor.new
    end

    def validate_profiles(parsed_form_data)
      return unless parsed_form_data.is_a?(Hash)

      validate_applicants(parsed_form_data['applicants']) if parsed_form_data['applicants']
      validate_veterans(parsed_form_data['veteran']) if parsed_form_data['veteran']
    end

    private

    def validate_applicants(applicants)
      return unless applicants.is_a?(Array)

      applicants.each do |applicant|
        next unless applicant.is_a?(Hash)

        # beneficiaries are labeled as applicants in 10-10D form data
        user_attributes = extract_user_attributes(applicant, 'applicant')
        validate_and_log_profile(user_attributes) if user_attributes
      end
    end

    def validate_veterans(veteran)
      return unless veteran.is_a?(Hash)

      user_attributes = extract_user_attributes(veteran, 'veteran')
      validate_and_log_profile(user_attributes) if user_attributes
    end

    def extract_user_attributes(person_data, person_type)
      # Handle different field structures for veterans vs applicants
      name_field = person_type == 'veteran' ? 'full_name' : 'applicant_name'
      dob_field = person_type == 'veteran' ? 'date_of_birth' : 'applicant_dob'

      return nil unless person_data[name_field]

      {
        first_name: person_data.dig(name_field, 'first'),
        last_name: person_data.dig(name_field, 'last'),
        birth_date: person_data[dob_field],
        ssn: person_data['ssn_or_tin'],
        person_type:
      }
    rescue => e
      Rails.logger.error "Error extracting user attributes for #{person_type}: #{e.message}"
      nil
    end

    def validate_and_log_profile(user_attributes)
      response = get_mpi_profile(user_attributes)

      if response.ok?
        @monitor.track_mpi_profile_found(user_attributes[:person_type])
        response.profile
      else
        @monitor.track_mpi_profile_not_found(user_attributes[:person_type], response.error&.message)
        nil
      end
    rescue MPI::Errors::RecordNotFound => e
      @monitor.track_mpi_profile_not_found(user_attributes[:person_type], e.message)
      nil
    rescue MPI::Errors::FailedRequestError, StandardError => e
      @monitor.track_mpi_service_error(user_attributes[:person_type], e.message)
      nil
    end

    def get_mpi_profile(user_attributes)
      @mpi_service.find_profile_by_attributes(
        first_name: user_attributes[:first_name],
        last_name: user_attributes[:last_name],
        birth_date: user_attributes[:birth_date],
        ssn: user_attributes[:ssn]
      )
    end
  end
end
