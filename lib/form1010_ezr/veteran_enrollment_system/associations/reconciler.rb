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

        UNKNOWN_NAME = 'UNKNOWN'
        UNKNOWN_RELATION = 'UNRELATED FRIEND'
        UNKNOWN_ROLE = 'Other emergency contact'

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
          transformed_ves_associations = transform_ves_associations(@ves_associations)
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
            obj['contactType'] = UNKNOWN_ROLE if obj['contactType'].blank?
            obj.merge('deleteIndicator' => true)
          end

          # Combine submitted array with deleted association objects
          @form_associations + associations_to_delete
        end

        private

        # Transform the VES Associations API data to match the EZR 'nextOfKins' and 'emergencyContacts' schemas.
        def transform_ves_association(association)
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
          ves_association['name'] = {} unless ves_association['name']
          first_name = ves_association.dig('name', 'givenName')
          last_name = ves_association.dig('name', 'familyName')
          ves_association['name']['givenName'] = UNKNOWN_NAME if first_name.blank?
          ves_association['name']['familyName'] = UNKNOWN_NAME if last_name.blank?

          NAME_MAPPINGS.each do |mapping|
            association['fullName'][mapping.first] = ves_association['name'][mapping.last.to_s]
          end
        end

        # VES can return an association with a blank relationship. We need to set a default value
        # in case the Veteran decides to delete this association, otherwise the update to VES will fail.
        def handle_relationship(association)
          relationship = association['relationType'] || UNKNOWN_RELATION
          relationship.gsub(/_/, ' ').split.join(' ')
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
