# frozen_string_literal: true

class RepresentationManagement::RswagConfig
  def config
    {
      'modules/representation_management/app/swagger/v0/swagger.json' => {
        openapi: '3.0.1',
        info:,
        tags:,
        components: {
          schemas:
        },
        paths: {},
        servers: [localhost, sandbox, staging, production]
      }
    }
  end

  def info
    {
      title: 'va.gov Representation Management API',
      version: '0.1.0',
      termsOfService: 'https://developer.va.gov/terms-of-service',
      description: 'A set of APIs powering the POA Widget, Find a Representative, and Appoint a Representative.'
    }
  end

  def tags
    [
      {
        name: 'PDF Generation',
        description: 'Generate a PDF form from user input'
      },
      {
        name: 'Power of Attorney',
        description: 'Retrieves the Power of Attorney for a veteran, if any.'
      },
      {
        name: 'Power of Attorney Requests',
        description: 'Digital Submission of VA Form 21-22'
      }
    ]
  end

  def schemas
    {
      accreditedIndividual: accredited_individual_schema,
      accreditedOrganization: accredited_organization_schema,
      error:,
      errors:,
      errorModel: error_model,
      powerOfAttorneyResponse: power_of_attorney_response,
      veteranServiceOrganization: veteran_service_organization_schema,
      veteranServiceRepresentative: veteran_service_representative_schema,
      poaRequest: poa_request_response
    }
  end

  def error_model
    {
      type: :object,
      required: [:errors],
      properties: {
        errors: {
          type: :array,
          items: {
            type: :object,
            required: [:title],
            properties: individual_detailed_error
          }
        }
      }
    }
  end

  def individual_detailed_error
    {
      title: { type: :string, example: 'Unprocessable Entity' },
      detail: { type: :string, example: 'Your request could not be processed' },
      code: { type: :string, example: '422' },
      status: { type: :string, example: '422' },
      meta: {
        type: :object,
        properties: {
          exception: { type: :string, example: 'UnprocessableEntity' },
          backtrace: {
            type: :array,
            items: { type: :string, example: 'stack trace line' }
          }
        }
      }
    }
  end

  def errors
    {
      type: :object,
      required: [:errors],
      properties: {
        errors: {
          type: :array,
          items: { '$ref' => '#/components/schemas/error' }
        }
      }
    }
  end

  def error
    {
      type: :string,
      example: "Veteran first name can't be blank"
    }
  end

  def power_of_attorney_response
    {
      type: :object,
      properties: {
        data: {
          type: :object,
          properties: {
            id: {
              type: :string,
              example: '123456'
            },
            type: {
              type: :string,
              description: 'Specifies the category of Power of Attorney (POA) representation.',
              enum: %w[representative organization]
            },
            attributes: power_of_attorney_attributes
          }
        }
      }
    }
  end

  def poa_request_response
    {
      type: :object,
      properties: {
        data: {
          type: :object,
          properties: {
            id: {
              type: :string,
              example: '0bfddcc5-fe3c-4ffb-a4c7-70f5e23bde23',
              description: 'The identifier of the newly created Power of Attorney Request'
            },
            type: poa_request_type,
            attributes: poa_request_attributes
          }
        }
      }
    }
  end

  def poa_request_type
    {
      type: :string,
      description: 'The type of resource created',
      example: 'power_of_attorney_request'
    }
  end

  def poa_request_attributes
    {
      type: :object,
      properties: {
        created_at: {
          type: :string,
          description: 'The timestamp of when the resource was created',
          example: '2020-01-01T12:00:00.000Z'
        },
        expires_at: {
          type: :string,
          description: 'The timestamp of when the resource expires',
          example: '2020-03-01T12:00:00.000Z'
        }
      },
      required: %w[created_at expires_at]
    }
  end

  def power_of_attorney_attributes
    {
      type: :object,
      properties: {
        type: {
          type: :string,
          example: 'representative',
          description: 'Type of Power of Attorney representation',
          enum: %w[organization representative]
        },
        individual_type: {
          type: :string,
          description: 'The type of individual appointed',
          enum: %w[attorney claim_agents veteran_service_officer],
          example: 'attorney'
        }
      }.merge(power_of_attorney_detailed_attributes),
      required: %w[type name address_line1 city state_code zip_code]
    }
  end

  def accredited_individual_schema
    individual_type_enum = %w[attorney claims_agent representative]
    accredited_org_ref = '#/components/schemas/accreditedOrganization'
    build_individual_schema(individual_type_enum, accredited_org_ref, 'individual')
  end

  def veteran_service_representative_schema
    individual_type_enum = %w[attorney claim_agents veteran_service_officer]
    accredited_org_ref = '#/components/schemas/veteranServiceOrganization'
    build_individual_schema(individual_type_enum, accredited_org_ref, 'representative', uuid: false)
  end

  def common_individual_attributes
    address_properties.merge(
      first_name: { type: :string, example: 'John' },
      last_name: { type: :string, example: 'Doe' },
      full_name: { type: :string, example: 'John Doe' },
      phone: { type: :string, example: '555-555-5555' },
      email: { type: :string, example: 'john.doe@example.com' }
    )
  end

  def build_individual_schema(individual_type_enum, accredited_org_ref, data_structure_type, uuid: true)
    attributes = common_individual_attributes.merge(
      individual_type: {
        type: :string,
        enum: individual_type_enum,
        example: individual_type_enum.first
      },
      accredited_organizations: {
        type: :object,
        properties: {
          data: {
            type: :array,
            items: { '$ref' => accredited_org_ref }
          }
        }
      }
    )
    accredited_data_structure(data_structure_type, attributes, uuid:)
  end

  def accredited_organization_schema
    build_organization_schema
  end

  def veteran_service_organization_schema
    optional_attributes = { can_accept_digital_poa_requests: { type: :boolean, example: true } }
    build_organization_schema(uuid: false, optional_attributes:)
  end

  def common_organization_attributes
    address_properties.merge(
      poa_code: { type: :string, example: '123' },
      name: { type: :string, example: 'Organization Name' },
      phone: { type: :string, example: '555-555-5555' },
      lat: { type: :number, format: :float, example: 37.7749, nullable: true },
      long: { type: :number, format: :float, example: -122.4194, nullable: true }
    )
  end

  def build_organization_schema(uuid: true, optional_attributes: {})
    attributes = common_organization_attributes.merge(optional_attributes)
    accredited_data_structure('organization', attributes, uuid:)
  end

  def accredited_data_structure(type, attributes, uuid: true)
    conditional_id = uuid ? '0bfddcc5-fe3c-4ffb-a4c7-70f5e23bde23' : '123456'
    {
      type: :object,
      properties: {
        data: {
          type: :object,
          properties: {
            id: { type: :string, example: conditional_id },
            type: { type: :string, example: type },
            attributes: {
              type: :object,
              properties: attributes
            }
          }
        }
      }
    }
  end

  def address_properties
    {
      address_line1: { type: :string, example: '123 Main St' },
      address_line2: { type: :string, example: 'Apt 4', nullable: true },
      address_line3: { type: :string, example: 'Suite 100', nullable: true },
      address_type: { type: :string, example: 'Domestic' },
      city: { type: :string, example: 'Anytown' },
      country_name: { type: :string, example: 'USA', nullable: true },
      country_code_iso3: { type: :string, example: 'USA', nullable: true },
      province: { type: :string, example: 'New York', nullable: true },
      international_postal_code: { type: :string, example: '', nullable: true },
      state_code: { type: :string, example: 'NY' },
      zip_code: { type: :string, example: '12345' },
      zip_suffix: { type: :string, example: '6789', nullable: true }
    }
  end

  def power_of_attorney_detailed_attributes
    {
      name: { type: :string, example: 'Bob Law' },
      address_line1: { type: :string, example: '1234 Freedom Blvd' },
      address_line2: { type: :string, example: 'Suite 200' },
      address_line3: { type: :string, example: 'Building 3' },
      address_type: { type: :string, example: 'DOMESTIC' },
      city: { type: :string, example: 'Arlington' },
      country_name: { type: :string, example: 'United States' },
      country_code_iso3: { type: :string, example: 'USA' },
      province: { type: :string, example: 'VA' },
      international_postal_code: { type: :string, example: '22204' },
      state_code: { type: :string, example: 'VA' },
      zip_code: { type: :string, example: '22204' },
      zip_suffix: { type: :string, example: '1234' },
      phone: { type: :string, example: '555-1234' },
      email: { type: :string, example: 'contact@example.org' }
    }
  end

  def localhost
    {
      url: 'http://localhost:3000',
      description: 'Local server',
      variables: {
        version: {
          default: 'v0'
        }
      }
    }
  end

  def sandbox
    {
      url: 'https://sandbox-api.va.gov',
      description: 'VA.gov API sandbox environment',
      variables: {
        version: {
          default: 'v0'
        }
      }
    }
  end

  def staging
    {
      url: 'https://staging-api.va.gov',
      description: 'VA.gov API staging environment',
      variables: {
        version: {
          default: 'v0'
        }
      }
    }
  end

  def production
    {
      url: 'https://api.va.gov',
      description: 'VA.gov API production environment',
      variables: {
        version: {
          default: 'v0'
        }
      }
    }
  end
end
