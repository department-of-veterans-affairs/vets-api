# frozen_string_literal: true

# In the Associations API, the following business logic is applied (as of 04/22/2025):
# ## when inserting a primary record, system will delete the other primary record on-file
# ## when inserting a secondary record
#  - if there are no primary record in the request or on-file,
#    then the record get promoted to primary, and any matching record on-file will be deleted
#  - if there is a primary record in the request or on-file,
#    than the secondary record on-file will be deleted
# ## when deleting a primary record, and if there is no primary record (in the request) to insert,
#    then the next secondary record in the request or on-file will be promoted to primary

require 'veteran_enrollment_system/associations/configuration'

module VeteranEnrollmentSystem
  module Associations
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include HCA::EnrollmentSystem

      configuration VeteranEnrollmentSystem::Associations::Configuration

      STATSD_KEY_PREFIX = 'api.veteran_enrollment_system.associations'

      UPDATED_STATUSES = %w[
        DELETED
        INSERTED
        UPDATED
      ].freeze

      NON_UPDATED_STATUSES = %w[
        NO_CHANGES
        NOT_DELETED_NO_MATCHING_ASSOCIATION
      ].freeze

      # We need to sort the associations in order to comply with the business logic
      # of the Associations API mentioned at the top of this file
      VES_ROLE_ORDER = {
        'OTHER_NEXT_OF_KIN' => 0,
        'OTHER_EMERGENCY_CONTACT' => 1,
        'PRIMARY_NEXT_OF_KIN' => 2,
        'EMERGENCY_CONTACT' => 3
      }.freeze

      ERROR_MAP = {
        400 => Common::Exceptions::BadRequest,
        404 => Common::Exceptions::ResourceNotFound,
        500 => Common::Exceptions::ExternalServerInternalServerError,
        504 => Common::Exceptions::GatewayTimeout
      }.freeze

      def initialize(current_user)
        super()
        @current_user = current_user
      end

      def get_associations(form_id)
        with_monitoring do
          response = perform(:get, "#{config.base_path}#{@current_user.icn}", nil)

          if response.status == 200
            response.body['data']['associations']
          else
            raise_error(response)
          end
        end
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.get_associations.failed")
        Rails.logger.error("#{form_id} retrieve associations failed: #{e.errors}")

        raise e
      end

      # @param [Array] associations: the associations to be updated
      # @param [String] form_id: the ID of the form that the associations are being updated for (e.g. '10-10EZR')
      def update_associations(associations, form_id)
        reordered_associations = reorder_associations(associations)

        # debugger

        with_monitoring do
          response = perform(
            :put,
            "#{config.base_path}#{@current_user.icn}",
            { 'associations' => reordered_associations }
          )

          handle_ves_update_response(response, form_id)
        end
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.update_associations.failed")
        Rails.logger.error("#{form_id} update associations failed: #{e.errors}")

        raise e
      end

      private

      # We need to sort the associations in order to comply with the business logic
      # of the Associations API mentioned at the top of this file
      def reorder_associations(associations)
        associations.sort_by { |assoc| VES_ROLE_ORDER[assoc['role']] }
      end

      def updated_associations(response)
        response.body['data']['associations'].select { |assoc| UPDATED_STATUSES.include?(assoc['status']) }
      end

      def non_updated_associations(response)
        response.body['data']['associations'].select { |assoc| NON_UPDATED_STATUSES.include?(assoc['status']) }
      end

      def set_response(
        status:,
        message:,
        **optional_fields
      )
        {
          status:,
          message:,
          timestamp: Time.current.iso8601
        }.merge(optional_fields)
      end

      def set_partial_success_response(response)
        set_response(
          status: 'partial_success',
          message: 'Some associations could not be updated',
          successful_records: updated_associations(response).map { |a| { role: a['role'], status: a['status'] } },
          failed_records: non_updated_associations(response).map { |a| { role: a['role'], status: a['status'] } }
        )
      end

      def set_ves_update_success_response(response, form_id)
        if response.body['messages'].find { |message| message['code'] == 'completed_partial' }
          StatsD.increment("#{STATSD_KEY_PREFIX}.update_associations.partial_success")
          Rails.logger.info(
            "The following #{form_id} associations could not be updated: " \
            "#{non_updated_associations(response).pluck('role').join(', ')}"
          )

          set_partial_success_response(response)
        else
          StatsD.increment("#{STATSD_KEY_PREFIX}.update_associations.success")
          Rails.logger.info("#{form_id} associations updated successfully")

          set_response(status: 'success', message: 'All associations were updated successfully')
        end
      end

      def raise_error(response)
        message = response.body['messages']&.pluck('description')&.join(', ') || response.body
        # Just in case the status is not in the ERROR_MAP, raise a BackendServiceException
        raise (
          ERROR_MAP[response.status] || Common::Exceptions::BackendServiceException
        ).new(errors: message)
      end

      def handle_ves_update_response(response, form_id)
        if response.status == 200
          set_ves_update_success_response(response, form_id)
        else
          raise_error(response)
        end
      end
    end
  end
end
