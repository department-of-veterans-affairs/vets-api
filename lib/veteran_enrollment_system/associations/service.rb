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

      # Associations API field names that are not nested
      FLAT_FIELDS = %w[
        role
        relationType
        primaryPhone
        alternatePhone
        lastUpdateDate
        deleteIndicator
      ].freeze

      NAME_MAPPINGS = [
        %i[first givenName],
        %i[middle middleName],
        %i[last familyName],
        %i[suffix suffix]
      ].freeze

      ADDRESS_MAPPINGS = [
        %i[street line1],
        %i[street2 line2],
        %i[street3 line3],
        %i[city city],
        %i[country country]
      ].freeze

      ROLE_MAPPINGS = [
        %i[Primary Next of Kin PRIMARY_NEXT_OF_KIN],
        %i[Other Next of Kin OTHER_NEXT_OF_KIN],
        %i[Emergency Contact EMERGENCY_CONTACT],
        %i[Other emergency contact OTHER_EMERGENCY_CONTACT]
      ].freeze

      UPDATED_STATUSES = %w[
        INSERTED
        UPDATED
        DELETED
      ].freeze

      NON_UPDATED_STATUSES = %w[
        NOT_DELETED_NO_MATCHING_ASSOCIATION
        NO_CHANGES
      ].freeze

      ERROR_MAP = {
        400 => Common::Exceptions::BadRequest,
        404 => Common::Exceptions::ResourceNotFound,
        500 => Common::Exceptions::ExternalServerInternalServerError,
        504 => Common::Exceptions::GatewayTimeout
      }.freeze

      def initialize(current_user, parsed_form = nil)
        super()
        @current_user = current_user
        @parsed_form = parsed_form
      end

      def get_associations(form_id)
        with_monitoring do
          response = perform(:get, "#{config.base_path}#{@current_user.icn}", nil)

          if response.status == 200
            response.body
          else
            raise_custom_error(response)
          end
        end
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.get_associations.failed")
        Rails.logger.info("#{form_id} retrieve associations failed: #{e.errors}")

        raise e
      end

      # @param [String] form_id: the ID of the form that the associations are being updated for (e.g. '10-10EZR')
      def update_associations(form_id)
        reconciled_associations = reconcile_associations(@parsed_form['nonPrefill']['veteranContacts'])
        reordered_associations = reorder_associations(reconciled_associations)
        transformed_associations = { 'associations' => transform_associations(reordered_associations) }

        with_monitoring do
          response = perform(
            :put,
            "#{config.base_path}#{@current_user.icn}",
            transformed_associations
          )

          handle_ves_update_response(response, form_id)
        end
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.update_associations.failed")
        Rails.logger.info("#{form_id} update associations failed: #{e.errors}")

        raise e
      end

      private

      # We need to sort the associations in order to comply with the business logic
      # of the Associations API mentioned at the top of this file
      def reorder_associations(associations)
        contact_type_order = {
          'Other Next of Kin' => 0,
          'Other emergency contact' => 1,
          'Primary Next of Kin' => 2,
          'Emergency Contact' => 3
        }

        associations.sort_by { |assoc| contact_type_order[assoc['contactType']] }
      end

      def transform_association(association)
        transformed_association = {}
        # Format the address to match the Associations schema
        transformed_association['address'] = format_address(association['address']).compact_blank
        # Format the name to match the Associations schema
        transformed_association['name'] = convert_full_name_alt(association['fullName']).compact_blank

        transform_flat_fields(association, transformed_association)
        # This is a required field in the Associations API for insert/update
        transformed_association['lastUpdateDate'] = Time.current.iso8601

        transformed_association
      end

      def transform_associations(associations)
        associations.map { |association| transform_association(association) }
      end

      # Transform the VES Associations API data to match the EZR veteranContacts schema
      def transform_ves_association(association)
        transformed_association = Common::HashHelpers.deep_compact(
          {
            fullName: {},
            relationship: association['relationType'],
            contactType: association['role'],
            primaryPhone: association['primaryPhone'].gsub(/[()\-]/, ''),
            address: get_address_from_association(association)
          }
        )
      end

      def transform_ves_associations(associations)
        associations.map { |association| transform_ves_association(association) }
      end

      # Transform non-nested fields to match the Associations API schema
      def transform_flat_fields(association, transformed_association)
        FLAT_FIELDS.each do |field|
          if field == 'role'
            transformed_association[field] = association['contactType'].to_s.upcase.gsub(/\s+/, '_')
          elsif field == 'relationType'
            transformed_association[field] =
              association['relationship'].to_s
                                         .gsub(/-/, '') # Remove hyphens
                                         .gsub(/\s+/, '_') # Replace spaces with underscores
                                         .gsub(%r{/}, '_') # Replace forward slashes with underscores
          elsif association[field].present?
            transformed_association[field] = association[field]
          end
        end
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

      def updated_associations(response)
        response.body['data']['associations'].select { |assoc| UPDATED_STATUSES.include?(assoc['status']) }
      end

      def non_updated_associations(response)
        response.body['data']['associations'].select { |assoc| NON_UPDATED_STATUSES.include?(assoc['status']) }
      end

      def handle_ves_update_response(response, form_id)
        if response.status == 200
          if response.body['messages'].find { |message| message['code'] != 'completed_partial' }
            StatsD.increment("#{STATSD_KEY_PREFIX}.update_associations.success")
            Rails.logger.info("#{form_id} associations updated successfully")

            set_response
          else
            StatsD.increment("#{STATSD_KEY_PREFIX}.update_associations.partial_success")
            Rails.logger.info(
              "The following #{form_id} associations could not be updated: " \
              "#{non_updated_associations(response).pluck('role').join(', ')}"
            )

            set_partial_success_response(response)
          end
        else
          raise_custom_error(response)
        end
      end

      def get_address_from_association(association)
        address = {}
        fill_address_mappings_from_association(address, association)
        fill_address_region_from_association(address, association)
        address
      end

      def fill_address_mappings_from_association(address, association)
        ADDRESS_MAPPINGS.each do |address_map|
          address[address_map.first] = association[address_map.last]
        end
      end

      def fill_address_region_from_association(address, association)
        case address[:country]
        when 'MEX'
          fill_mexico_address_from_association(address, association)
        when 'USA'
          fill_usa_address_from_association(address, association)
        else
          fill_other_address_from_association(address, association)
        end
      end

      def fill_mexico_address_from_association(address, association)
        address['state'] = HCA::OverridesParser::STATE_OVERRIDES['MEX'].invert[address['state']]
        address['postalCode'] = association['address']['postalCode']
      end

      def fill_usa_address_from_association(address, association)
        address['state'] = association['address']['state']
        zip_code = association['address']['zipCode']
        zip_plus4 = association['address']['zipPlus4']
        address['postalCode'] = zip_plus4.present? ? "#{zip_code}-#{zip_plus4}" : zip_code
      end

      def fill_other_address_from_association(address, association)
        address['state'] = association['address']['provinceCode']
        address['postalCode'] = association['address']['postalCode']
      end

      def fill_contact_full_name_from_association(contact, association)
        NAME_MAPPINGS.each do |mapping|
          contact[:fullName][mapping.first] = association['fullName'][mapping.last]
        end
      end

      # We need to reconcile the associations data from VES with the submitted form data in order
      # to ensure we are sending the correct data to the Associations API in case any updates were made or records
      # were deleted.
      # @return [Array] the reconciled associations data that will be sent to the Associations API
      def reconcile_associations
        ves_associations = get_associations(@current_user.icn)

        form_associations = @parsed_form['veteranContacts']
        # Create a lookup set of contactTypes in the submitted array.
        # We'll use this to find missing objects (e.g. objects that were deleted on the frontend)
        submitted_contact_types = form_associations.pluck('contactType').compact.to_set
        # Find missing associations based on contactType
        missing_associations = ves_associations.reject do |obj|
          submitted_contact_types.include?(obj['contactType'])
        end
        # Add a deleteIndicator to the missing objects. The user deleted these objects on the frontend,
        # so we need to delete them from the Associations API
        associations_to_delete = missing_associations.map do |obj|
          obj.merge('deleteIndicator' => true)
        end
        # Combine submitted array with deleted objects
        form_associations + associations_to_delete
      end

      def raise_custom_error(response)
        message = response.body['messages']&.pluck('description')&.join(', ') || response.body
        # Just in case the status is not in the ERROR_MAP, raise a BackendServiceException
        raise (
          ERROR_MAP[response.status] || Common::Exceptions::BackendServiceException
        ).new(errors: message)
      end
    end
  end
end
