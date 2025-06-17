# frozen_string_literal: true

require 'veteran_enrollment_system/associations/service'
require 'veteran_enrollment_system/associations/configuration'
require 'form1010_ezr/veteran_enrollment_system/associations/reconciler'

module Form1010Ezr
  module VeteranEnrollmentSystem
    module Associations
      class Service < ::VeteranEnrollmentSystem::Associations::Service
        include HCA::EnrollmentSystem

        configuration ::VeteranEnrollmentSystem::Associations::Configuration

        STATSD_KEY_PREFIX = 'api.1010ezr.veteran_enrollment_system.associations'

        # Associations API field names that are not nested
        FLAT_FIELDS = %w[
          alternatePhone
          deleteIndicator
          lastUpdateDate
          primaryPhone
          relationType
          role
        ].freeze

        FORM_ID = '10-10EZR'

        def reconcile_and_update_associations(form_associations)
          ves_associations = get_associations(FORM_ID)
          reconciled_associations = Form1010Ezr::VeteranEnrollmentSystem::Associations::Reconciler.new(
            ves_associations,
            form_associations
          ).reconcile_associations

          update_associations(reconciled_associations)
        rescue => e
          StatsD.increment("#{STATSD_KEY_PREFIX}.reconcile_and_update_associations.failed")
          Rails.logger.error(
            "#{FORM_ID} reconciling and updating associations failed: " \
            "#{e.respond_to?(:errors) ? e.errors.first[:detail] : e.message}"
          )
          raise e
        end

        private

        def update_associations(associations)
          transformed_associations = transform_associations(associations)

          super(transformed_associations, '10-10EZR')
        end

        # We need to reconcile the associations data from VES with the associations data in the submitted form in order
        # to ensure we are sending the correct data to the Associations API in case any records were deleted.
        # @return [Array] the reconciled associations data that will be sent to the Associations API
        def reconcile_associations(ves_associations, form_associations)
          transformed_ves_associations = transform_ves_associations(ves_associations)
          # Create a lookup set of contactTypes in the submitted array.
          # We'll use this to find missing association objects (e.g. associations that were deleted on the frontend)
          submitted_contact_types = form_associations.map { |obj| obj['contactType']&.downcase }.compact.to_set
          # Find missing associations based on contactType (case insensitive)
          missing_associations = transformed_ves_associations.reject do |obj|
            submitted_contact_types.include?(obj['contactType']&.downcase)
          end

          return form_associations if missing_associations.empty?

          # Add a deleteIndicator to the missing association objects. The user deleted these associations
          # on the frontend, so we need to delete them from the Associations API
          associations_to_delete = missing_associations.map do |obj|
            obj.merge('deleteIndicator' => true)
          end

          # Combine submitted array with deleted association objects
          form_associations + associations_to_delete
        end

        # Transform the submitted form data to match the Associations API schema
        def transform_association(association)
          transformed_association = {}
          # Format the address to match the Associations schema
          transformed_association['address'] = format_address(association['address']).compact_blank
          # Format the name to match the Associations schema
          transformed_association['name'] = convert_full_name_alt(association['fullName']).compact_blank

          transform_flat_fields(association, transformed_association)
          # This is a required field in the Associations API for insert/update, but not for delete
          unless transformed_association['deleteIndicator']
            transformed_association['lastUpdateDate'] = Time.current.iso8601
          end

          transformed_association
        end

        def transform_associations(associations)
          associations.map { |association| transform_association(association) }
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
      end
    end
  end
end
