# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'

module VAOS
  module V2
    class RelationshipsService < VAOS::SessionService
      def get_patient_relationships(clinic_service_id, facility_id)
        with_monitoring do
          params = {
            clinicalService: clinic_service_id,
            location: facility_id
          }

          response = perform(:get, "/vpg/v1/patients/#{user.icn}/relationships", params, headers)
          relationships = response[:body][:data][:relationships].map { |relationship| OpenStruct.new(relationship) }

          data = VAOS::V2::VAOSSerializer.new.serialize(relationships, 'relationship')
          data.each { |relationship| relationship.delete(:id) }

          { data:, meta: partial_errors(response) }
        end
      end

      private

      def partial_errors(response)
        return { failures: [] } if response.body[:failures].blank?

        log_partial_errors(response)

        {
          failures: response.body[:failures]
        }
      end

      # Logs partial errors from a response.
      #
      # @param response [Faraday::Env] The response object containing the status and body.
      #
      # @return [nil]
      #
      def log_partial_errors(response)
        return unless response.status == 200

        failures_dup = response.body[:failures].deep_dup
        failures_dup.each do |failure|
          detail = failure[:detail]
          failure[:detail] = VAOS::Anonymizers.anonymize_icns(detail) if detail.present?
        end

        log_message_to_sentry(
          'VAOS::V2::RelationshipsService#get_patient_relationships has response errors.',
          :info,
          failures: failures_dup.to_json
        )
      end
    end
  end
end
