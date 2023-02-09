# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

module ClaimsApi
  module LocalBGS
    # This service is used to store information about individuals the VA is
    # interested in. This information may be kept permanently, removed or discarded
    # if appropriate.
    class PersonWebService < ClaimsApi::LocalBGS::Base
      # Plural of 'Person' is 'People' not 'Persons'
      def self.service_name
        'people'
      end

      # Find a Person, as defined by the Person Web Service, by their SSN.
      def find_by_ssn(ssn)
        response = request(:find_person_by_ssn, ssn: ssn)
        response.body[:find_person_by_ssn_response][:person_dto]
      end

      # Find a Person, as defined by the Person Web Service, by their File
      # Number.
      def find_by_file_number(file_number)
        response = request(:find_person_by_file_number, fileNumber: file_number)
        response.body[:find_person_by_file_number_response][:person_dto]
      end

      def find_person_by_ptcpnt_id(participant_id, ssn = nil)
        response = request(:find_person_by_ptcpnt_id, { ptcpntId: participant_id }, ssn)
        response.body[:find_person_by_ptcpnt_id_response][:person_dto]
      end

      def find_relationships_by_ptcpnt_id_relationship_type(participant_id, type)
        response = request(:find_relationships_by_ptcpnt_id_relationship_type, ptcpntId: participant_id, type: type)
        response.body[:find_relationships_by_ptcpnt_id_relationship_type_response][:person_dto]
      end

      def find_employee_by_participant_id(participant_id)
        response = request(:find_employee_by_ptcpnt_id, ptcpntId: participant_id)
        response.body[:find_employee_by_ptcpnt_id_response][:employee_dto]
      end

      # this method can take an 8 digit file number or a 9 digit SSN
      def find_dependents(file_number)
        response = request(:find_dependents, fileNumber: file_number)
        response.body[:find_dependents_response][:dependent_dto]
      end
    end
  end
end
