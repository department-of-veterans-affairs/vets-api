# frozen_string_literal: true

require_dependency 'appeals_api/form_schemas'

class AppealsApi::V1::NoticeOfDisagreementsControllerSwagger
  include Swagger::Blocks

  NOD_TAG = ['Notice of Disagreements'].freeze

  read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }
  read_json = ->(path) { JSON.parse(read_file.call(path)) }
  read_json_from_same_dir = ->(filename) { read_json.call(['app', 'swagger', 'appeals_api', 'v1', filename]) }

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

  swagger_path '/notice_of_disagreements/schema' do
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

      response :default do
        key :description, 'unexpected error'
        content 'application/json' do
          schema do
            key :type, :object
            key :required, [:errors]
            property :errors do
              key :type, :array
              items do
                key :description, 'Errors with some details for the given request'

                key :required, %i[status detail]
                property :status do
                  key :type, :integer
                  key :format, :int32
                  key :example, '500'
                  key :description, 'Standard 500 Response for Server Side issues'
                end

                property :detail do
                  key :type, :string
                  key :example, 'Something went wrong on our end. Try again soon.'
                  key :description, 'A more detailed message about why an error occured'
                end
              end
            end
          end
        end
      end
    end
  end
end
