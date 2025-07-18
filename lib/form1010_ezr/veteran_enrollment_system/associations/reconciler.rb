# frozen_string_literal: true

require 'common/hash_helpers'

module Form1010Ezr
  module VeteranEnrollmentSystem
    module Associations
      class Reconciler
        NAME_MAPPINGS = [
          %w[first givenName],
          %w[middle middleName],
          %w[last familyName],
          %w[suffix suffix]
        ].freeze

        VES_ROLE_MAPPINGS = {
          'PRIMARY_NEXT_OF_KIN' => 'Primary Next of Kin',
          'EMERGENCY_CONTACT' => 'Emergency Contact',
          'OTHER_NEXT_OF_KIN' => 'Other Next of Kin',
          'OTHER_EMERGENCY_CONTACT' => 'Other emergency contact'
        }.freeze

        # @param [Array] ves_associations The associations data from VES
        # @param [Array] form_associations The associations data in the submitted form
        def initialize(ves_associations, form_associations)
          @ves_associations = ves_associations
          @form_associations = form_associations
        end

        # Reconcile the associations data from VES with the associations data in the submitted form in order
        # to ensure we are sending the correct data to the Associations API in case any records were deleted.
        # @return [Array] The reconciled associations data that will be sent to the Associations API
        def reconcile_associations
          # As of 07/18/2025, we are not sending OTHER_NEXT_OF_KIN or OTHER_EMERGENCY_CONTACT data to the Associations API
          transformed_ves_associations = 
            transform_ves_associations(
              @ves_associations.reject { |obj| obj['role'] == 'OTHER_NEXT_OF_KIN' || obj['role'] == 'OTHER_EMERGENCY_CONTACT' }
            )
          # Create a lookup set of contactTypes in the submitted array.
          # We'll use this to find missing association objects (e.g. associations that were deleted on the frontend)
          submitted_contact_types = @form_associations.map { |obj| obj['contactType']&.downcase }.compact.to_set
          # Find missing associations based on contactType (case insensitive)
          missing_associations = transformed_ves_associations.reject do |obj|
            submitted_contact_types.include?(obj['contactType']&.downcase)
          end

          return @form_associations if missing_associations.empty?

          # Add a deleteIndicator to the missing association objects. The user deleted these associations
          # on the frontend, so we need to delete them from the Associations API
          associations_to_delete = missing_associations.map do |obj|
            obj.merge('deleteIndicator' => true)
          end

          # Combine submitted array with deleted association objects
          @form_associations + associations_to_delete
        end

        private

        # Transform the VES Associations API data to match the EZR 'nextOfKins' and 'emergencyContacts' schemas.
        def transform_ves_association(association)
          validate_required_fields!(association)

          transformed_association = build_transformed_association(association)
          fill_association_full_name_from_ves_association(transformed_association, association)

          Common::HashHelpers.deep_remove_blanks(transformed_association).compact_blank
        rescue => e
          Rails.logger.error("Error transforming VES association: #{e.message}")
          raise e
        end

        def transform_ves_associations(associations)
          associations.map { |association| transform_ves_association(association) }
        end

        def fill_association_full_name_from_ves_association(association, ves_association)
          NAME_MAPPINGS.each do |mapping|
            association['fullName'][mapping.first] = ves_association['name'][mapping.last.to_s]
          end
        end

        # There are instances where a VES association may have a 'relationship' field
        def handle_relationship(association)
          relationship = association['relationship'] || association['relationType']

          return relationship if relationship.blank?

          relationship.gsub(/_/, ' ').split.join(' ')
        end

        def validate_required_fields!(association)
          missing_fields = []
          missing_fields << 'role' if association['role'].blank?
          missing_fields << 'name' if association['name'].blank?
          missing_fields << 'relationship' if handle_relationship(association).blank?

          return if missing_fields.empty?

          raise StandardError, "VES association is missing the following field(s): #{missing_fields.join(', ')}"
        end

        def build_transformed_association(association)
          {
            'contactType' => VES_ROLE_MAPPINGS[association['role']],
            'fullName' => {},
            'relationship' => handle_relationship(association)
          }
        end
      end
    end
  end
end
