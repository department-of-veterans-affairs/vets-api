# frozen_string_literal: true

module Ask
  module Iris
    module Oracle
      def self.transform_country(value)
        ::Ask::Iris::Constants::COUNTRIES[value]
      end

      def self.transform_state(value)
        ::Ask::Iris::Constants::STATES[value]
      end

      def self.transform_date(value)
        temp_value = value.split('-')
        temp_value[1] + '-' + temp_value[2] + '-' + temp_value[0]
      end

      FIELD_LIST = [
        {
          schemaKey: 'topic.levelOne',
          fieldName: 'rn_ProductCategoryInput_3_Product_Button',
          fieldType: FieldTypes::OracleCustomDropdownField
        },
        {
          schemaKey: 'topic.levelTwo',
          fieldName: 'rn_ProductCategoryInput_3_Product_Button',
          fieldType: FieldTypes::OracleCustomDropdownField
        },
        {
          schemaKey: 'topic.levelThree',
          fieldName: 'rn_ProductCategoryInput_3_Product_Button',
          fieldType: FieldTypes::OracleCustomDropdownField
        },
        {
          schemaKey: 'topic.vaMedicalCenter',
          fieldName: 'Incident.CustomFields.c.medical_centers',
          fieldType: FieldTypes::DropdownField
        },
        {
          schemaKey: 'query',
          fieldName: 'Incident.Threads',
          fieldType: FieldTypes::TextAreaField
        },
        {
          schemaKey: 'inquiryType',
          fieldName: 'rn_ProductCategoryInput_6_Category_Button',
          fieldType: FieldTypes::OracleCustomDropdownField
        },
        {
          schemaKey: 'veteranStatus.veteranStatus',
          fieldName: 'Incident.CustomFields.c.vet_status',
          fieldType: FieldTypes::DropdownField,
          transform: lambda { |value|
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
          schemaKey: 'veteranStatus.isDependent',
          fieldName: 'Incident.CustomFields.c.inquirer_is_dependent',
          fieldType: FieldTypes::RadioField
        },
        {
          schemaKey: 'veteranStatus.relationshipToVeteran',
          fieldName: 'Incident.CustomFields.c.relation_to_vet',
          fieldType: FieldTypes::DropdownField
        },
        {
          schemaKey: 'veteranStatus.veteranIsDeceased',
          fieldName: 'Incident.CustomFields.c.vet_dead',
          fieldType: FieldTypes::RadioField
        },
        {
          schemaKey: 'preferredContactMethod',
          fieldName: 'Incident.CustomFields.c.form_of_response',
          fieldType: FieldTypes::DropdownField,
          transform: lambda { |value|
            contact_methods = { 'email' => 'E-Mail', 'phone' => 'Telephone', 'mail' => 'US Mail' }
            contact_methods[value]
          }
        },
        {
          schemaKey: 'fullName.first',
          fieldName: 'Incident.CustomFields.c.first_name',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'fullName.last',
          fieldName: 'Incident.CustomFields.c.last_name',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'email',
          fieldName: 'Incident.CustomFields.c.incomingemail',
          fieldType: FieldTypes::EmailField
        },
        {
          schemaKey: 'phone',
          fieldName: 'Incident.CustomFields.c.telephone_number',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'address.country',
          fieldName: 'Incident.CustomFields.c.country',
          fieldType: FieldTypes::DropdownField,
          transform: ->(value) { transform_country(value) }
        },
        {
          schemaKey: 'address.street',
          fieldName: 'Incident.CustomFields.c.street',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'address.city',
          fieldName: 'Incident.CustomFields.c.city',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'address.state',
          fieldName: 'Incident.CustomFields.c.state',
          fieldType: FieldTypes::DropdownField,
          transform: ->(value) { transform_state(value) }
        },
        {
          schemaKey: 'address.postalCode',
          fieldName: 'Incident.CustomFields.c.zipcode',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'dependentInformation.relationshipToVeteran',
          fieldName: 'Incident.CustomFields.c.dep_relation_to_vet',
          fieldType: FieldTypes::DropdownField
        },
        {
          schemaKey: 'dependentInformation.first',
          fieldName: 'Incident.CustomFields.c.dep_first_name',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'dependentInformation.last',
          fieldName: 'Incident.CustomFields.c.dep_last_name',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'dependentInformation.phone',
          fieldName: 'Incident.CustomFields.c.dep_telephone_number',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'dependentInformation.email',
          fieldName: 'Incident.CustomFields.c.dep_incomingemail',
          fieldType: FieldTypes::EmailField
        },
        {
          schemaKey: 'dependentInformation.address.country',
          fieldName: 'Incident.CustomFields.c.dep_country',
          fieldType: FieldTypes::DropdownField,
          transform: ->(value) { transform_country(value) }
        },
        {
          schemaKey: 'dependentInformation.address.street',
          fieldName: 'Incident.CustomFields.c.dep_street',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'dependentInformation.address.city',
          fieldName: 'Incident.CustomFields.c.dep_city',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'dependentInformation.address.state',
          fieldName: 'Incident.CustomFields.c.dep_state',
          fieldType: FieldTypes::DropdownField,
          transform: ->(value) { transform_state(value) }
        },
        {
          schemaKey: 'dependentInformation.address.postalCode',
          fieldName: 'Incident.CustomFields.c.dep_zipcode',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranInformation.first',
          fieldName: 'Incident.CustomFields.c.vet_first_name',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranInformation.last',
          fieldName: 'Incident.CustomFields.c.vet_last_name',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranInformation.phone',
          fieldName: 'Incident.CustomFields.c.vet_phone',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranInformation.email',
          fieldName: 'Incident.CustomFields.c.vet_email',
          fieldType: FieldTypes::EmailField
        },
        {
          schemaKey: 'veteranInformation.address.country',
          fieldName: 'Incident.CustomFields.c.vet_country',
          fieldType: FieldTypes::DropdownField,
          transform: ->(value) { transform_country(value) }
        },
        {
          schemaKey: 'veteranInformation.address.street',
          fieldName: 'Incident.CustomFields.c.vet_street',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranInformation.address.city',
          fieldName: 'Incident.CustomFields.c.vet_city',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranInformation.address.state',
          fieldName: 'Incident.CustomFields.c.vet_state',
          fieldType: FieldTypes::DropdownField,
          transform: ->(value) { transform_state(value) }
        },
        {
          schemaKey: 'veteranInformation.address.postalCode',
          fieldName: 'Incident.CustomFields.c.vet_zipcode',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranServiceInformation.branchOfService',
          fieldName: 'Incident.CustomFields.c.service_branch',
          fieldType: FieldTypes::DropdownField
        },
        {
          schemaKey: 'veteranServiceInformation.socialSecurityNumber',
          fieldName: 'Incident.CustomFields.c.ssn',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranServiceInformation.claimNumber',
          fieldName: 'Incident.CustomFields.c.claim_number',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranServiceInformation.serviceNumber',
          fieldName: 'Incident.CustomFields.c.service_number',
          fieldType: FieldTypes::TextField
        },
        {
          schemaKey: 'veteranServiceInformation.dateOfBirth',
          fieldName: 'Incident.CustomFields.c.date_of_birth',
          fieldType: FieldTypes::TextField,
          transform: ->(value) { transform_date(value) }
        },
        {
          schemaKey: 'veteranServiceInformation.serviceDateRange.from',
          fieldName: 'Incident.CustomFields.c.e_o_d',
          fieldType: FieldTypes::TextField,
          transform: ->(value) { transform_date(value) }
        },
        {
          schemaKey: 'veteranServiceInformation.serviceDateRange.to',
          fieldName: 'Incident.CustomFields.c.released_from_duty',
          fieldType: FieldTypes::TextField,
          transform: ->(value) { transform_date(value) }
        }
      ].freeze
    end
  end
end
