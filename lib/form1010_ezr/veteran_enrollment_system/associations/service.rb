# frozen_string_literal: true

require 'veteran_enrollment_system/associations/service'
require 'veteran_enrollment_system/associations/configuration'
require 'form1010_ezr/veteran_enrollment_system/associations/reconciler'
require 'common/hash_helpers'

module Form1010Ezr
  module VeteranEnrollmentSystem
    module Associations
      class Service < ::VeteranEnrollmentSystem::Associations::Service
        include HCA::EnrollmentSystem

        configuration ::VeteranEnrollmentSystem::Associations::Configuration

        STATSD_KEY_PREFIX = 'api.1010ezr.veteran_enrollment_system.associations'

        # Associations API field names that are not nested
        FLAT_FIELDS = %w[
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

        # Transform the submitted form data to match the Associations API schema
        def transform_association(association)
          transformed_association = {}
          # Format the address to match the Associations schema
          transformed_association['address'] = format_address(association['address'])
          # Format the name to match the Associations schema
          transformed_association['name'] = convert_full_name_alt(association['fullName'], all_caps: false)

          transform_flat_fields(association, transformed_association)
          # This is a required field in the Associations API for insert/update, but not for delete
          if transformed_association['deleteIndicator'].blank?
            transformed_association['lastUpdateDate'] = Time.current.iso8601
          end

          # Remove blank values
          Common::HashHelpers.deep_remove_blanks(transformed_association).compact_blank
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
