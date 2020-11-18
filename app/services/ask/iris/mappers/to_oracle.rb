# frozen_string_literal: true

require_relative '../constants/states.rb'
require_relative '../constants/countries.rb'

module Ask
  module Iris
    module Mappers
      class ToOracle
        include States
        include Countries
        class Field
          attr_accessor :schema_key, :field_type, :field_name

          def initialize(properties)
            @schema_key = properties[:schemaKey]
            @field_name = properties[:fieldName]
            @field_type = properties[:fieldType]
            @transform = properties[:transform]
          end

          def transform(value)
            return value if @transform.nil?

            @transform.call(value)
          end
        end

        def self.make_field_list(field_list)
          field_list.map do |field_properties|
            Field.new(field_properties)
          end
        end

        FIELD_LIST = make_field_list [
          {
            "schemaKey": 'veteranStatus.veteranStatus',
            "fieldName": 'Incident.CustomFields.c.vet_status',
            "fieldType": 'select_list',
            "transform": lambda { |value|
              vet_statuses = {
                'dependent' => 'for the Dependent of a Veteran',
                'general' => 'General Question (Vet Info Not Needed)',
                'vet' => 'for Myself as a Veteran (I am the Vet)',
                'behalf of vet' => 'for, about, or on behalf of a Veteran'
              }
              vet_statuses[value]
            }
          },
          {
            "schemaKey": 'veteranStatus.isDependent',
            "fieldName": 'Incident.CustomFields.c.inquirer_is_dependent',
            "fieldType": 'radio'
          },
          {
            "schemaKey": 'veteranStatus.relationshipToVeteran',
            "fieldName": 'Incident.CustomFields.c.relation_to_vet',
            "fieldType": 'select_list'
          },
          {
            "schemaKey": 'veteranStatus.veteranIsDeceased',
            "fieldName": 'Incident.CustomFields.c.vet_dead',
            "fieldType": 'radio'
          },
          {
            "schemaKey": 'preferredContactMethod',
            "fieldName": 'Incident.CustomFields.c.form_of_response',
            "fieldType": 'select_list',
            "transform": lambda { |value|
              contact_methods = { 'email' => 'E-Mail', 'phone' => 'Telephone', 'mail' => 'US Mail' }
              contact_methods[value]
            }
          },
          {
            "schemaKey": 'fullName.first',
            "fieldName": 'Incident.CustomFields.c.first_name',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'fullName.last',
            "fieldName": 'Incident.CustomFields.c.last_name',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'email',
            "fieldName": 'Incident.CustomFields.c.incomingemail',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'phone',
            "fieldName": 'Incident.CustomFields.c.telephone_number',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'address.country',
            "fieldName": 'Incident.CustomFields.c.country',
            "fieldType": 'select_list',
            "transform": ->(value) { transform_country(value) }
          },
          {
            "schemaKey": 'address.street',
            "fieldName": 'Incident.CustomFields.c.street',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'address.city',
            "fieldName": 'Incident.CustomFields.c.city',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'address.state',
            "fieldName": 'Incident.CustomFields.c.state',
            "fieldType": 'select_list',
            "transform": ->(value) { transform_state(value) }
          },
          {
            "schemaKey": 'address.postalCode',
            "fieldName": 'Incident.CustomFields.c.zipcode',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'dependentInformation.relationshipToVeteran',
            "fieldName": 'Incident.CustomFields.c.dep_relation_to_vet',
            "fieldType": 'select_list'
          },
          {
            "schemaKey": 'dependentInformation.first',
            "fieldName": 'Incident.CustomFields.c.dep_first_name',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'dependentInformation.last',
            "fieldName": 'Incident.CustomFields.c.dep_last_name',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'dependentInformation.phone',
            "fieldName": 'Incident.CustomFields.c.dep_telephone_number',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'dependentInformation.email',
            "fieldName": 'Incident.CustomFields.c.dep_incomingemail',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'dependentInformation.address.country',
            "fieldName": 'Incident.CustomFields.c.dep_country',
            "fieldType": 'select_list',
            "transform": ->(value) { transform_country(value) }
          },
          {
            "schemaKey": 'dependentInformation.address.street',
            "fieldName": 'Incident.CustomFields.c.dep_street',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'dependentInformation.address.city',
            "fieldName": 'Incident.CustomFields.c.dep_city',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'dependentInformation.address.state',
            "fieldName": 'Incident.CustomFields.c.dep_state',
            "fieldType": 'select_list',
            "transform": ->(value) { transform_state(value) }
          },
          {
            "schemaKey": 'dependentInformation.address.postalCode',
            "fieldName": 'Incident.CustomFields.c.dep_zipcode',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranInformation.first',
            "fieldName": 'Incident.CustomFields.c.vet_first_name',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranInformation.last',
            "fieldName": 'Incident.CustomFields.c.vet_last_name',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranInformation.phone',
            "fieldName": 'Incident.CustomFields.c.vet_phone',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranInformation.email',
            "fieldName": 'Incident.CustomFields.c.vet_email',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranInformation.address.country',
            "fieldName": 'Incident.CustomFields.c.vet_country',
            "fieldType": 'select_list',
            "transform": ->(value) { transform_country(value) }
          },
          {
            "schemaKey": 'veteranInformation.address.street',
            "fieldName": 'Incident.CustomFields.c.vet_street',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranInformation.address.city',
            "fieldName": 'Incident.CustomFields.c.vet_city',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranInformation.address.state',
            "fieldName": 'Incident.CustomFields.c.vet_state',
            "fieldType": 'select_list',
            "transform": ->(value) { transform_state(value) }
          },
          {
            "schemaKey": 'veteranInformation.address.postalCode',
            "fieldName": 'Incident.CustomFields.c.vet_zipcode',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranServiceInformation.branchOfService',
            "fieldName": 'Incident.CustomFields.c.service_branch',
            "fieldType": 'select_list'
          },
          {
            "schemaKey": 'veteranServiceInformation.socialSecurityNumber',
            "fieldName": 'Incident.CustomFields.c.ssn',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranServiceInformation.claimNumber',
            "fieldName": 'Incident.CustomFields.c.claim_number',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranServiceInformation.serviceNumber',
            "fieldName": 'Incident.CustomFields.c.service_number',
            "fieldType": 'text_field'
          },
          {
            "schemaKey": 'veteranServiceInformation.dateOfBirth',
            "fieldName": 'Incident.CustomFields.c.date_of_birth',
            "fieldType": 'text_field',
            "transform": ->(value) { transform_date(value) }
          },
          {
            "schemaKey": 'veteranServiceInformation.serviceDateRange.from',
            "fieldName": 'Incident.CustomFields.c.e_o_d',
            "fieldType": 'text_field',
            "transform": ->(value) { transform_date(value) }
          },
          {
            "schemaKey": 'veteranServiceInformation.serviceDateRange.to',
            "fieldName": 'Incident.CustomFields.c.released_from_duty',
            "fieldType": 'text_field',
            "transform": ->(value) { transform_date(value) }
          }
        ].freeze

        def self.transform_country(value)
          COUNTRIES[value]
        end

        def self.transform_state(value)
          STATES[value]
        end

        def self.transform_date(value)
          temp_value = value.split('-')
          temp_value[1] + '-' + temp_value[2] + '-' + temp_value[0]
        end
      end
    end
  end
end
