# frozen_string_literal: true

require 'veteran_enrollment_system/associations/service'
require 'veteran_enrollment_system/associations/configuration'

module Form1010Ezr
  module VeteranEnrollmentSystem
    module Associations
      class Service < ::VeteranEnrollmentSystem::Associations::Service
        configuration ::VeteranEnrollmentSystem::Associations::Configuration
        # Associations API field names that are not nested
        FLAT_FIELDS = %w[
          alternatePhone
          deleteIndicator
          lastUpdateDate
          primaryPhone
          relationType
          role
        ].freeze

        FIELD_MAPPINGS = [
          %w[contactType role],
          %w[relationship relationType]
        ].freeze

        NAME_MAPPINGS = [
          %w[first givenName],
          %w[middle middleName],
          %w[last familyName],
          %w[suffix suffix]
        ].freeze

        ADDRESS_MAPPINGS = [
          %w[street line1],
          %w[street2 line2],
          %w[street3 line3],
          %w[city city],
          %w[country country]
        ].freeze

        VES_ROLE_MAPPINGS = {
          'PRIMARY_NEXT_OF_KIN' => 'Primary Next of Kin',
          'EMERGENCY_CONTACT' => 'Emergency Contact',
          'OTHER_NEXT_OF_KIN' => 'Other Next of Kin',
          'OTHER_EMERGENCY_CONTACT' => 'Other emergency contact'
        }.freeze

        def initialize(current_user)
          super(current_user)
        end

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

        private

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

        # Transform the VES Associations API data to match the EZR veteranContacts schema
        def transform_ves_association(association)
          transformed_association = {
            'address' => get_address_from_association(association),
            'alternatePhone' => sanitize_phone_number(association['alternatePhone']),
            'contactType' => VES_ROLE_MAPPINGS[association['role']],
            'fullName' => {},
            'primaryPhone' => sanitize_phone_number(association['primaryPhone']),
            'relationship' => remove_underscores(association['relationType'])
          }
          fill_association_full_name_from_ves_association(transformed_association, association)

          Common::HashHelpers.deep_compact(transformed_association)
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

        def get_address_from_association(association)
          address = {}
          fill_address_mappings_from_association(address, association)
          fill_address_region_from_association(address, association)
          address
        end

        def fill_address_mappings_from_association(address, association)
          ADDRESS_MAPPINGS.each do |address_map|
            address[address_map.first] = association['address'][address_map.last.to_s]
          end
        end

        def fill_address_region_from_association(address, association)
          case address['country']
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

        def fill_association_full_name_from_ves_association(association, ves_association)
          NAME_MAPPINGS.each do |mapping|
            association['fullName'][mapping.first] = ves_association['name'][mapping.last.to_s]
          end
        end

        def remove_underscores(string)
          string.gsub(/_/, ' ').split.join(' ')
        end

        def sanitize_phone_number(phone_number)
          phone_number.gsub(/[()\-]/, '')
        end
      end
    end
  end
end