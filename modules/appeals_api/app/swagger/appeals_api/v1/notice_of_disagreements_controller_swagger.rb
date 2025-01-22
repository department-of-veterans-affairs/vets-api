# frozen_string_literal: true

require 'appeals_api/form_schemas'

# rubocop:disable Layout/LineLength, Metrics/ClassLength
class AppealsApi::V1::NoticeOfDisagreementsControllerSwagger
  include Swagger::Blocks

  PATH_ENABLED_FOR_ENV = Settings.modules_appeals_api.documentation.path_enabled_flag

  NOD_TAG = ['Notice of Disagreements'].freeze

  read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }
  read_json = ->(path) { JSON.parse(read_file.call(path)) }
  read_json_from_same_dir = ->(filename) { read_json.call(['app', 'swagger', 'appeals_api', 'v1', filename]) }

  ERROR_500_EXAMPLE = {
    errors: [
      {
        status: '500',
        detail: 'An unknown error has occurred.',
        code: '151',
        title: 'Internal Server Error'
      }
    ],
    status: 500
  }.freeze

  nod_json_schema = AppealsApi::V1::NodJsonSchemaSwaggerHelper.new

  swagger_path '/notice_of_disagreements' do
    operation :post, tags: NOD_TAG do
      key :deprecated, true
      key :summary, 'Creates a new Notice of Disagreement.'

      description = 'Submits an appeal of type Notice of Disagreement.' \
                    'This endpoint is the same as submitting [VA Form 10182](https://www.va.gov/vaforms/va/pdf/VA10182.pdf)' \
                    ' via mail or fax directly to the Board of Veterans’ Appeals.'
      key :description, description

      key :operationId, 'nodCreateRoot'

      key :parameters, nod_json_schema.params
      key :requestBody, nod_json_schema.request_body
      key :responses, nod_json_schema.responses
      security do
        key :apikey, []
      end
    end
  end

  swagger_path '/notice_of_disagreements/{uuid}' do
    operation :get, tags: NOD_TAG do
      key :deprecated, true
      key :operationId, 'getNoticeOfDisagreement'
      key :summary, 'Shows a specific Notice of Disagreement. (a.k.a. the Show endpoint)'
      key :description, 'Returns all of the data associated with a specific Notice of Disagreement.'
      parameter name: 'uuid', in: 'path', required: true, description: 'Notice of Disagreement UUID' do
        schema { key :$ref, :uuid }
      end

      response 200 do
        key :description, 'Info about a single Notice of Disagreement.'

        content 'application/json' do
          schema do
            key :type, :object

            property :data do
              property :id do
                key :$ref, :uuid
              end

              property :type do
                key :type, :string
                key :enum, [:noticeOfDisagreement]
              end

              property :attributes do
                key :type, :object

                property :status do
                  key :type, :string
                  key :description, 'nodStatus'
                  key :$ref, '#/components/schemas/nodStatus'
                end
                property :updatedAt do
                  key :$ref, '#/components/schemas/timeStamp'
                end
                property :createdAt do
                  key :$ref, '#/components/schemas/timeStamp'
                end
                property :formData do
                  key :$ref, '#/components/schemas/nodCreateInput'
                end
              end
            end
          end
        end
      end

      response 404 do
        key :description, 'Notice of Disagreement not found'
        content 'application/json' do
          schema do
            key :type, :object
            property :errors do
              key :type, :array

              items do
                property :status do
                  key :type, :integer
                  key :example, 404
                end
                property :detail do
                  key :type, :string
                  key :example, 'NoticeOfDisagreement with uuid {uuid} not found.'
                end
              end
            end
          end
        end
      end

      security do
        key :apikey, []
      end
    end
  end

  swagger_path '/notice_of_disagreements/contestable_issues' do
    operation :get, tags: NOD_TAG do
      key :deprecated, true
      key :operationId, 'getNODContestableIssues'

      key :summary, 'Returns all contestable issues for a specific veteran.'

      description = 'Returns all issues associated with a Veteran that have' \
                    ' been decided by a Notice of Disagreement' \
                    'as of the `receiptDate`. Not all issues returned are guaranteed to be eligible for appeal.' \
                    'Associate these results when creating a new Notice of Disagreement.'
      key :description, description

      parameter name: 'X-VA-SSN', in: 'header', description: 'veteran\'s ssn' do
        key :description, 'Either X-VA-SSN or X-VA-File-Number is required'
        schema '$ref': 'X-VA-SSN'
      end

      parameter name: 'X-VA-File-Number', in: 'header', description: 'veteran\'s file number' do
        key :description, 'Either X-VA-SSN or X-VA-File-Number is required'
        schema type: :string
      end

      parameter name: 'X-VA-Receipt-Date', in: 'header', required: true do
        desc = '(yyyy-mm-dd) In order to determine contestability of issues, ' \
               'the receipt date of a hypothetical Decision Review must be specified.'
        key :description, desc

        schema type: :string, format: :date
      end

      parameter name: 'X-VA-ICN', in: 'header', description: 'veteran\'s icn' do
        key :description, 'Veteran\'s ICN'
        schema type: :string
      end

      key :responses, read_json_from_same_dir['responses_contestable_issues.json']
      security do
        key :apikey, []
      end
    end
  end

  swagger_path '/notice_of_disagreements/schema' do
    operation :get do
      key :deprecated, true
      key :summary, 'Gets the Notice of Disagreement JSON Schema.'
      key :operationId, 'getNodJsonSchema'
      desc = 'Returns the [JSON Schema](https://json-schema.org/) for the `POST /notice_of_disagreement` endpoint.'
      key :description, desc
      key :produces, [
        'application/json'
      ]
      key :tags, [
        'Notice of Disagreements'
      ]

      security do
        key :apikey, []
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
                key :$ref, :errorModel
              end
            end
          end
        end
      end
    end
  end

  swagger_path '/notice_of_disagreements/validate' do
    operation :post, tags: NOD_TAG do
      key :deprecated, true
      key :summary, 'Validates a POST request body against the JSON schema.'
      desc = 'Like the `POST /notice_of_disagreement`, but *only* does the validations **—does not submit anything.**'
      key :description, desc
      key :operationId, 'nodValidateSchema'

      security do
        key :apikey, []
      end

      parameter do
        key :name, 'X-VA-First-Name'
        key :in, :header
        key :description, 'First Name of Veteran referenced in Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Last-Name'
        key :in, :header
        key :description, 'Last Name of Veteran referenced in Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'XVA-SSN'
        key :in, :header
        key :description, 'SSN of Veteran referenced in Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-Birth-Date'
        key :in, :header
        key :description, 'Birth Date of Veteran referenced in Notice of Disagreement'
        key :required, true
        key :type, :string
      end

      parameter do
        key :name, 'X-VA-File-Number'
        key :in, :header
        key :required, false
        key :description, 'VA file number'
      end

      parameter do
        key :name, 'X-VA-Birth-Date'
        key :in, :header
        key :required, false
        key :description, 'The birth date of the Veteran referenced in the Notice of Disagreement.'
      end

      request_body do
        key :required, true
        content 'application/json' do
          schema do
            key :$ref, :nodCreateInput
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
        key :description, 'Unknown Error'
        content 'application/json' do
          schema do
            key :type, :object
            property :errors do
              key :type, :array

              items do
                key :$ref, :errorModel
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
                key :$ref, :errorModel
              end
            end
          end
        end
      end
    end
  end

  swagger_path '/notice_of_disagreements/evidence_submissions' do
    operation :post, tags: NOD_TAG do
      key :deprecated, true
      key :operationId, 'postNoticeOfDisagreementEvidenceSubmission'
      key :summary, 'Get a location for subsequent evidence submission document upload PUT request'
      key :description, <<~DESC
        This is the first step to submitting supporting evidence for an NOD.  (See the Evidence Uploads section above for additional information.)

        The Notice of Disagreement GUID that is returned when the NOD is submitted, is supplied to this endpoint to ensure the NOD is in a valid state for sending supporting evidence documents.  Only NODs that selected the Evidence Submission lane are allowed to submit evidence documents up to 90 days after the NOD is received by VA.
      DESC
      parameter name: 'nod_uuid', in: 'path', required: true, description: 'Associated Notice of Disagreement UUID' do
        schema { key :$ref, :uuid }
      end

      response 202 do
        key :description, 'Accepted. Location generated'
        content 'application/json' do
          schema do
            key :type, :object
            key :required, %i[data]
            property :data do
              key :description, 'Status record for a previously initiated document submission.'
              key :required, %i[id type attributes]
              property :id do
                key :description, 'JSON API identifier'
                key :type, :string
                key :format, :uuid
                key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
              end

              property :type do
                key :description, 'JSON API type specification'
                key :type, :string
                key :example, 'document_upload'
              end

              property :attributes do
                key :required, %i[guid status]
                property :guid do
                  key :description, 'The document upload identifier'
                  key :type, :string
                  key :format, :uuid
                  key :example, '6d8433c1-cd55-4c24-affd-f592287a7572'
                end

                property :status do
                  key :type, :string
                  key :enum, %i[pending ...]
                  key :example, 'pending'
                end

                property :code do
                  key :type, :string
                end

                property :detail do
                  key :description, 'Human readable error detail. Only present if status = "error"'
                  key :type, :string
                end

                property :location do
                  key :description, 'Location to which to PUT document Payload'
                  key :type, :string
                  key :format, :uri
                  key :example, 'https://sandbox-api.va.gov/example_path_here/{idpath}'
                end

                property :updated_at do
                  key :description, 'The last time the submission was updated'
                  key :type, :string
                  key :format, 'date-time'
                  key :example, '2018-07-30T17:31:15.958Z'
                end

                property :uploaded_pdf do
                  key :description, 'Only populated after submission starts processing'
                  key :example, 'null'
                end
              end
            end
          end
        end
      end

      response 400 do
        key :description, 'Bad Request'
        content 'application/json' do
          schema do
            key :type, :object
            property :errors do
              key :type, :array

              items do
                property :status do
                  key :type, :integer
                  key :example, 400
                end
                property :detail do
                  key :type, :string
                  key :example, 'Must supply a corresponding NOD id in order to submit evidence'
                end
              end
            end
          end
        end
      end

      response 404 do
        key :description, 'Associated Notice of Disagreement not found'
        content 'application/json' do
          schema do
            key :type, :object
            property :errors do
              key :type, :array

              items do
                property :status do
                  key :type, :integer
                  key :example, 404
                end
                property :detail do
                  key :type, :string
                  key :example, 'The record identified by {nod_uuid} not found.'
                end
              end
            end
          end
        end
      end

      response 422 do
        key :description, 'Validation errors'
        content 'application/json' do
          schema do
            key :type, :object

            property :title do
              key :type, :string
              key :enum, [:unprocessable_entity]
              key :example, 'unprocessable_entity'
            end

            property :detail do
              key :type, :string
              key :enum,
                  ["Request header 'X-VA-SSN' does not match the associated Notice of Disagreement's SSN",
                   "Corresponding Notice of Disagreement 'boardReviewOption' must be 'evidence_submission'"]
              key :example, "Corresponding Notice of Disagreement 'boardReviewOption' must be 'evidence_submission'"
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
        key :description, 'Unknown Error'

        content 'application/json' do
          schema do
            key :type, :object
            key :example, ERROR_500_EXAMPLE
            property :errors do
              key :type, :array
              items do
                key :$ref, :errorModel
              end
            end
          end
        end
      end

      security do
        key :apikey, []
      end
    end
  end

  swagger_path '/path' do
    operation :put, tags: NOD_TAG do
      key :deprecated, true
      key :operationId, 'putNoticeOfDisagreementEvidenceSubmission'
      key :description, File.read(AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'v1', 'put_description.md'))
      key :summary, 'Accepts Notice of Disagreement Evidence Submission document upload.'

      parameter do
        key :name, 'Content-MD5'
        key :in, 'header'
        key :description, 'Base64-encoded 128-bit MD5 digest of the message. Use for integrity control.'
        key :required, false
        schema do
          key :type, :string
          key :format, :md5
        end
      end

      response 200 do
        key :description, 'Document upload staged'
      end

      response 400 do
        key :description, 'Document upload failed'
        content 'application/xml' do
          schema do
            key :type, :object
            key :description, 'Document upload failed'

            xml do
              key :name, 'Error'
            end

            property :Code do
              key :type, :string
              key :description, 'Error code'
              key :example, 'Bad Digest'
            end

            property :Message do
              key :type, :string
              key :description, 'Error detail'
              key :example, 'A client error (InvalidDigest) occurred when calling the PutObject operation -' \
                            'The Content-MD5 you specified was invalid.'
            end

            property :Resource do
              key :type, :string
              key :description, 'Resource description'
              key :example, '/example_path_here/6d8433c1-cd55-4c24-affd-f592287a7572.upload'
            end

            property :RequestId do
              key :type, :string
              key :description, 'Identifier for debug purposes'
            end
          end
        end
      end
    end
  end

  swagger_path '/notice_of_disagreements/evidence_submissions/{uuid}' do
    operation :get, tags: NOD_TAG do
      key :deprecated, true
      key :operationId, 'getNoticeOfDisagreementEvidenceSubmission'
      key :summary, 'Shows a specific Notice of Disagreement Evidence Submission.'
      key :description, 'Returns all of the data associated with a specific Notice of Disagreement Evidence Submission.'
      parameter name: 'uuid', in: 'path', required: true do
        schema { key :$ref, :uuid }
        key :description, 'Notice of Disagreement UUID Evidence Submission'
      end

      response 200 do
        key :description, 'Info about a single Notice of Disagreement Evidence Submission.'

        content 'application/json' do
          schema do
            key :type, :object

            property :data do
              property :id do
                key :$ref, :uuid
              end

              property :type do
                key :type, :string
                key :enum, [:evidenceSubmission]
              end

              property :status do
                key :type, :string
                key :description, 'evidenceSubmissionStatus'
                key :$ref, '#/components/schemas/evidenceSubmissionStatus'
              end
            end
          end
        end
      end

      response 404 do
        key :description, 'Notice of Disagreement Evidence Submission not found'
        content 'application/json' do
          schema do
            key :type, :object
            property :errors do
              key :type, :array

              items do
                property :status do
                  key :type, :integer
                  key :example, 404
                end
                property :detail do
                  key :type, :string
                  key :example, 'NoticeOfDisagreement Evidence Submission with uuid {uuid} not found.'
                end
              end
            end
          end
        end
      end

      security do
        key :apikey, []
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Metrics/ClassLength
