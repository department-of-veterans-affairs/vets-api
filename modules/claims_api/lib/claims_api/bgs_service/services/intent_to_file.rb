# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

module ClaimsApi
  module LocalBGS
    class IntentToFileWebService < ClaimsApi::LocalBGS::Base
      def bean_name
        'IntentToFileWebServiceBean'
      end

      def self.service_name
        'intent_to_file'
      end

      def find_intent_to_file_by_participant_id(participant_id)
        response = request(
          :find_intent_to_file_by_ptcpnt_id, ptcpntId: participant_id
        )
        response.body[:find_intent_to_file_by_ptcpnt_id_response][:intent_to_file_dto]
      end

      def insert_intent_to_file(options)
        validate_required_keys(required_insert_intent_to_file_fields, options, __method__.to_s)
        missing_claimant_attributes!(options: options)

        request_body = {
          itfTypeCd: options[:intent_to_file_type_code],
          ptcpntVetId: options[:participant_vet_id],
          rcvdDt: options[:received_date],
          signtrInd: options[:signature_indicated],
          submtrApplcnTypeCd: options[:submitter_application_icn_type_code]
        }
        request_body[:ptcpntClmantId] = options[:participant_claimant_id] if options.key?(:participant_claimant_id)
        request_body[:clmantSsn] = options[:claimant_ssn] if options.key?(:claimant_ssn)

        response = request(
          :insert_intent_to_file,
          {
            intentToFileDTO: request_body
          },
          options[:ssn]
        )
        response.body[:insert_intent_to_file_response][:intent_to_file_dto]
      end

      def update_intent_to_file(options)
        validate_required_keys(required_update_intent_to_file_fields, options, __method__.to_s)

        response = request(
          :update_intent_to_file,
          {
            intentToFileDTO: {
              createDt: options[:created_date],
              intentToFileId: options[:intent_to_file_id],
              itfStatusTypeCd: options[:intent_to_file_status_code],
              itfTypeCd: options[:intent_to_file_type_code],
              rcvdDt: options[:received_date],
              submtrAppIcnTypeCd: options[:submitter_application_icn_type_code],
              submtrApplcnTypeCd: options[:submitter_application_icn_type_code],
              ptcpntVetId: options[:participant_vet_id],
              ptcpntClmantId: options[:participant_claimant_id],
              vetFileNbr: options[:veteran_file_number]
            }
          },
          options[:ssn]
        )
        response.body[:update_intent_to_file_response][:intent_to_file_dto]
      end

      def find_intent_to_file_by_ptcpnt_id_itf_type_cd(participant_id, itf_type)
        response = request(
          :find_intent_to_file_by_ptcpnt_id_itf_type_cd, ptcpntId: participant_id, itfTypeCd: itf_type
        )
        response.body[:find_intent_to_file_by_ptcpnt_id_itf_type_cd_response][:intent_to_file_dto]
      end

      private

      def required_insert_intent_to_file_fields
        %i[
          intent_to_file_type_code
          participant_vet_id
          received_date
          submitter_application_icn_type_code
        ]
      end

      def required_update_intent_to_file_fields
        %i[
          intent_to_file_id
          intent_to_file_type_code
          received_date
          submitter_application_icn_type_code
        ]
      end

      def missing_claimant_attributes!(options:)
        return if options.key?(:participant_claimant_id)
        return if options.key?(:claimant_ssn)

        raise(ArgumentError, "Must include either 'participant_claimant_id' or 'claimant_ssn'")
      end
    end
  end
end
