# frozen_string_literal: true

require_dependency 'appeals_api/form_schemas'

class AppealsApi::V1::NoticeOfDisagreementsControllerSwagger
  include Swagger::Blocks

  PATH_ENABLED_FOR_ENV = Settings.modules_appeals_api.documentation.notice_of_disagreements_v1

  NOD_TAG = ['Notice of Disagreements'].freeze

  read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }
  read_json = ->(path) { JSON.parse(read_file.call(path)) }
  read_json_from_same_dir = ->(filename) { read_json.call(['app', 'swagger', 'appeals_api', 'v1', filename]) }

  ERROR_500_EXAMPLE = {
    "errors": [
      {
        "status": '500',
        "detail": 'An unknown error has occurred.',
        "code": '151',
        "title": 'Internal Server Error'
      }
    ],
    "status": 500
  }.freeze

  swagger_path '/notice_of_disagreements/contestable_issues' do
    operation :get, tags: NOD_TAG do
      key :operationId, 'getNODContestableIssues'

      key :summary, 'Returns all contestable issues for a specific veteran.'

      desc = 'Returns all issues a Veteran could contest in a Notice of Disagreement as of the `receiptDate` ' \
        'Associate these results when creating new Decision Reviews.'
      key :description, desc

      parameter name: 'X-VA-SSN', 'in': 'header', description: 'veteran\'s ssn' do
        key :description, 'Either X-VA-SSN or X-VA-File-Number is required'
        schema '$ref': 'X-VA-SSN'
      end

      parameter name: 'X-VA-File-Number', 'in': 'header', description: 'veteran\'s file number' do
        key :description, 'Either X-VA-SSN or X-VA-File-Number is required'
        schema type: :string
      end

      parameter name: 'X-VA-Receipt-Date', 'in': 'header', required: true do
        desc = '(yyyy-mm-dd) In order to determine contestability of issues, ' \
          'the receipt date of a hypothetical Decision Review must be specified.'
        key :description, desc

        schema type: :string, 'format': :date
      end

      key :responses, read_json_from_same_dir['responses_contestable_issues.json']
      security do
        key :apikey, []
      end
    end
  end

  swagger_path '/v1/decision_reviews/notice_of_disagreements' do
    next unless PATH_ENABLED_FOR_ENV

    operation :post, tags: NOD_TAG do
      key :summary, 'Creates a new Notice of Disagreement.'
      key :description, ''
      key :operationId, 'nodCreateRoot'

      parameter do
        key :name, 'X-VA-First-Name'
        key :in, :header
        key :description, 'First Name of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Last-Name'
        key :in, :header
        key :description, 'Last Name of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'XVA-SSN'
        key :in, :header
        key :description, 'SSN of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Birth-Date'
        key :in, :header
        key :description, 'Birth Date of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Veteran-File-Number'
        key :in, :header
        key :required, false
        key :description, 'VA file number'
      end

      parameter do
        key :name, 'X-VA-Veteran-Birth-Date'
        key :in, :header
        key :required, false
        key :description, 'The birth date of the Veteran referenced in the decision review request.'
      end

      parameter do
        key :name, 'X-VA-Claimant-First-Name'
        key :in, :header
        key :required, false
        key :description, 'The first name of the benefits claimant (if applicable)'
      end

      parameter do
        key :name, 'X-VA-Claimant-Middle-Initial'
        key :in, :header
        key :required, false
        key :description, 'The middle initial of the benefits claimant (if applicable)'
      end

      parameter do
        key :name, 'X-VA-Claimant-Last-Name'
        key :in, :header
        key :required, false
        key :description, 'The last name of the benefits claimant (if applicable)'
      end

      parameter do
        key :name, 'X-VA-Claimant-Birth-Date'
        key :in, :header
        key :required, false
        key :description, 'The birth date of the benefits claimant (if applicable)'
      end

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :nodCreateInput
          end
        end
      end

      response 200 do
        key :description, '10182 success response'
        content 'application/json' do
          schema do
            key :'$ref', :nodCreateResponse
          end
        end
      end

      response 422 do
        key :description, '10182 validation errors'
        content 'application/json' do
          schema do
            key :type, :object
            property :errors do
              key :type, :array

              items do
                key :'$ref', :errorModel
              end
            end

            property :status do
              key :type, :integer
              key :description, 'Standard HTTP error response code.'
              key :example, 422
            end
          end
        end
      end

      response 500 do
        key :description, '10182 validation errors'

        content 'application/json' do
          schema do
            key :type, :object
            key :example, ERROR_500_EXAMPLE
            property :errors do
              key :type, :array
              items do
                key :'$ref', :errorModel
              end
            end
          end
        end
      end
    end
  end

  swagger_path '/notice_of_disagreements/validate' do
    next unless PATH_ENABLED_FOR_ENV

    operation :post, tags: NOD_TAG do
      key :summary, 'Validates the schema provided to create a NOD'
      key :description, ''
      key :operationId, 'nodValidateSchema'

      parameter do
        key :name, 'X-VA-First-Name'
        key :in, :header
        key :description, 'First Name of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Last-Name'
        key :in, :header
        key :description, 'Last Name of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'XVA-SSN'
        key :in, :header
        key :description, 'SSN of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Birth-Date'
        key :in, :header
        key :description, 'Birth Date of Veteran creating the Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Veteran-File-Number'
        key :in, :header
        key :required, false
        key :description, 'VA file number'
      end

      parameter do
        key :name, 'X-VA-Veteran-Birth-Date'
        key :in, :header
        key :required, false
        key :description, 'The birth date of the Veteran referenced in the decision review request.'
      end

      parameter do
        key :name, 'X-VA-Claimant-First-Name'
        key :in, :header
        key :required, false
        key :description, 'The first name of the benefits claimant (if applicable)'
      end

      parameter do
        key :name, 'X-VA-Claimant-Middle-Initial'
        key :in, :header
        key :required, false
        key :description, 'The middle initial of the benefits claimant (if applicable)'
      end

      parameter do
        key :name, 'X-VA-Claimant-Last-Name'
        key :in, :header
        key :required, false
        key :description, 'The last name of the benefits claimant (if applicable)'
      end

      parameter do
        key :name, 'X-VA-Claimant-Birth-Date'
        key :in, :header
        key :required, false
        key :description, 'The birth date of the benefits claimant (if applicable)'
      end

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :'$ref', :nodCreateInput
          end
        end
      end

      response 200 do
        key :description, '10182 success response'
        content 'application/json' do
          schema do
            key :type, :object
            property :data do
              property :type do
                key :type, :string
                key :example, 'noticeOfDisagreementValidation'
                key :description, 'schema type'
              end

              property :attributes do
                key :type, :object

                property :status do
                  key :type, :string
                  key :example, 'valid'
                end
              end
            end
          end
        end
      end

      response 422 do
        key :description, '10182 validation errors'
        content 'application/json' do
          schema do
            key :type, :object
            property :errors do
              key :type, :array

              items do
                key :'$ref', :errorModel
              end
            end

            property :status do
              key :type, :integer
              key :description, 'Standard HTTP error response code.'
              key :example, 422
            end
          end
        end
      end

      response 500 do
        key :description, '10182 validation errors'
        content 'application/json' do
          schema do
            key :type, :object
            key :example, ERROR_500_EXAMPLE
            property :errors do
              key :type, :array

              items do
                key :'$ref', :errorModel
              end
            end
          end
        end
      end
    end
  end

  swagger_path '/notice_of_disagreements/schema' do
    next unless PATH_ENABLED_FOR_ENV

    operation :get do
      key :summary, 'Get Notice of Disagreement JSON Schema'
      key :operationId, 'getNodJsonSchema'
      key :description, 'Returns a sample Notice of Disagreements JSON Schema'
      key :produces, [
        'application/json'
      ]
      key :tags, [
        'Notice of Disagreements'
      ]

      security do
        key :bearer_token, []
      end

      response 200 do
        key :description, 'schema response'
        content 'application/json' do
          schema do
            key :type, :object
            key :required, [:data]
            property :data do
              key :type, :array
              items do
                key :type, :object
                key :description, 'Returning JSON Schema Objects'
                key :example, AppealsApi::FormSchemas.new.schema('10182')
              end
            end
          end
        end
      end

      response 500 do
        key :description, 'Internal Error response'
        content 'application/json' do
          schema do
            key :type, :object
            key :example, ERROR_500_EXAMPLE
            property :errors do
              key :type, :array

              items do
                key :'$ref', :errorModel
              end
            end
          end
        end
      end
    end
  end
end
