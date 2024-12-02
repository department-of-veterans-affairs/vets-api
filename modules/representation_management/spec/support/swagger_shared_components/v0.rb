# frozen_string_literal: true

module SwaggerSharedComponents
  class V0
    def self.body_examples
      {
        original_entities_parameter:,
        pdf_generator2122:,
        pdf_generator2122_parameter:
      }
    end

    def self.pdf_generator2122
      {
        record_consent: '',
        consent_address_change: '',
        consent_limits: [],
        claimant:,
        representative:,
        veteran:
      }
    end

    def self.claimant
      {
        date_of_birth: '1980-12-31',
        relationship: 'Spouse',
        phone: '5555555555',
        email: 'claimant@example.com',
        name:,
        address:
      }
    end

    def self.representative
      {
        id: '8c3b3b53-02a1-4dbd-bd23-2b556f5ef635',
        organization_id: '6f76b9c2-2a37-4cd7-8a6c-93a0b3a73943'
      }
    end

    def self.veteran
      {
        ssn: '123456789',
        va_file_number: '123456789',
        date_of_birth: '1980-12-31',
        service_number: '123456789',
        service_branch: 'ARMY',
        phone: '5555555555',
        email: 'veteran@example.com',
        name:,
        address:
      }
    end

    def self.original_entities_parameter
      {
        name: :accredited_entities_for_appoint,
        in: :body,
        schema: {
          type: :object,
          properties: {
            query: { type: :string, example: 'Bob' }
          },
          required: %w[query]
        }
      }
    end

    def self.pdf_generator2122_parameter
      {
        name: :pdf_generator2122,
        in: :body,
        schema: {
          type: :object,
          properties: appointment_conditions_parameter.merge(
            claimant: claimant_parameter,
            representative: representative_parameter,
            veteran: veteran_parameter
          ),
          required: %w[record_consent veteran]
        }
      }
    end

    def self.appointment_conditions_parameter
      {
        record_consent: { type: :boolean, example: true },
        consent_address_change: { type: :boolean, example: false },
        consent_limits: {
          type: :array,
          items: { type: :string },
          example: %w[ALCOHOLISM DRUG_ABUSE HIV SICKLE_CELL]
        }
      }
    end

    def self.claimant_parameter
      {
        type: :object,
        properties: {
          name: name_parameters,
          address: address_parameters,
          date_of_birth: { type: :string, format: :date, example: '1980-12-31' },
          relationship: { type: :string, example: 'Spouse' },
          phone: { type: :string, example: '1234567890' },
          email: { type: :string, example: 'veteran@example.com' }
        }
      }
    end

    def self.representative_parameter
      {
        type: :object,
        properties: {
          id: { type: :string, example: '8c3b3b53-02a1-4dbd-bd23-2b556f5ef635' },
          organization_id: { type: :string, example: '6f76b9c2-2a37-4cd7-8a6c-93a0b3a73943' }
        }
      }
    end

    def self.veteran_parameter
      {
        type: :object,
        properties: {
          name: name_parameters,
          address: address_parameters,
          ssn: { type: :string, example: '123456789' },
          va_file_number: { type: :string, example: '123456789' },
          date_of_birth: { type: :string, format: :date, example: '1980-12-31' },
          service_number: { type: :string, example: '123456789' },
          service_branch: { type: :string, example: 'Army' },
          service_branch_other: { type: :string, example: 'Other Branch' },
          phone: { type: :string, example: '1234567890' },
          email: { type: :string, example: 'veteran@example.com' }
        }
      }
    end

    def self.name_parameters
      {
        type: :object,
        properties: {
          first: { type: :string, example: 'John' },
          middle: { type: :string, example: 'Middle' },
          last: { type: :string, example: 'Doe' }
        }
      }
    end

    def self.name
      {
        first: 'John',
        middle: 'Middle',
        last: 'Doe'
      }
    end

    def self.address_parameters
      {
        type: :object,
        properties: {
          address_line1: { type: :string, example: '123 Main St' },
          address_line2: { type: :string, example: 'Apt 1' },
          city: { type: :string, example: 'Springfield' },
          state_code: { type: :string, example: 'IL' },
          country: { type: :string, example: 'US' },
          zip_code: { type: :string, example: '62704' },
          zip_code_suffix: { type: :string, example: '6789' }
        }
      }
    end

    def self.address
      {
        address_line1: '123 Main St',
        address_line2: '',
        city: 'Springfield',
        state_code: 'IL',
        country: 'US',
        zip_code: '62704',
        zip_code_suffix: '6798'
      }
    end
  end
end
