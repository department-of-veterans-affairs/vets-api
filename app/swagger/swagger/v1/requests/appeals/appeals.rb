# frozen_string_literal: true

require 'decision_review/schemas'

class Swagger::V1::Requests::Appeals::Appeals
  include Swagger::Blocks

  swagger_path '/decision_reviews/v1/higher_level_reviews' do
    operation :post do
      key :tags, %w[higher_level_reviews]
      key :summary, 'Creates a higher level review'
      key :operationId, 'createHigherLevelReview'
      description = 'Sends data to Lighthouse who Creates a filled-out HLR PDF and uploads it to Central Mail.' \
                    ' NOTE: If `informalConference` is false, the fields `informalConferenceRep`' \
                    ' and `informalConferenceTime` cannot be present.'
      key :description, description

      parameter do
        key :name, :request
        key :in, :body
        key :required, true
        schema '$ref': :hlrCreate
      end

      response 200 do
        key :description, 'Submitted'
        schema '$ref': :hlrShowRoot
      end

      response 422 do
        key :description, 'Malformed request'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/higher_level_reviews/{uuid}' do
    operation :get do
      key :description, 'This endpoint returns the details of a specific Higher Level Review'
      key :operationId, 'showHigherLevelReview'
      key :tags, %w[higher_level_reviews]

      parameter do
        key :name, :uuid
        key :in, :path
        key :description, 'UUID of a higher level review'
        key :required, true
        key :type, :string
        key :format, :uuid
        key :pattern, '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      end

      response 200 do
        key :description, 'Central Mail status and original payload for Higher-Level Review'
        schema '$ref': :hlrShowRoot
      end

      response 404 do
        key :description, 'ID not found'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/higher_level_reviews/contestable_issues/{benefit_type}' do
    operation :get do
      description =
        'For the logged-in veteran, returns a list of issues that could be contested in a Higher-Level Review ' \
        'for the specified benefit type.'
      key :description, description
      key :operationId, 'getContestableIssues'
      key :tags, %w[higher_level_reviews]

      parameter do
        key :name, :benefit_type
        key :in, :path
        key :required, true
        key :type, :string
        key :enum, VetsJsonSchema::SCHEMAS.fetch('HLR-GET-CONTESTABLE-ISSUES-REQUEST-BENEFIT-TYPE_V1')['enum']
      end

      response 200 do
        key :description, 'Issues'
        schema '$ref': :hlrContestableIssues
      end

      response 404 do
        key :description, 'Veteran not found'
        schema '$ref': :Errors
      end

      response 422 do
        key :description, 'Malformed request'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/notice_of_disagreements' do
    operation :post do
      key :tags, %w[notice_of_disagreements]
      key :summary, 'Creates a notice of disagreement'
      key :operationId, 'createNoticeOfDisagreement'
      description = 'Submits an appeal of type Notice of Disagreement, to be passed on to lighthouse. ' \
                    'This endpoint is effectively the same as submitting VA Form 10182 via mail or fax directly' \
                    ' to the Board of Veterans’ Appeals.'
      key :description, description

      parameter do
        key :name, :request
        key :in, :body
        key :required, true
        schema '$ref': :nodCreate
      end

      response 200 do
        key :description, 'Submitted'
        schema '$ref': :nodShowRoot
      end

      response 422 do
        key :description, 'Malformed request'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/notice_of_disagreements/{uuid}' do
    operation :get do
      key :description, 'This endpoint returns the details of a specific notice of disagreement'
      key :operationId, 'showNoticeOfDisagreement'
      key :tags, %w[notice_of_disagreements]

      parameter do
        key :name, :uuid
        key :in, :path
        key :description, 'UUID of a notice of disagreement'
        key :required, true
        key :type, :string
        key :format, :uuid
        key :pattern, '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      end

      response 200 do
        key :description, 'status and original payload for Notice of Disagreement'
        schema '$ref': :nodShowRoot
      end

      response 404 do
        key :description, 'ID not found'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/notice_of_disagreements/contestable_issues' do
    operation :get do
      description =
        'For the logged-in veteran, returns a list of issues that could be contested in a Notice of Disagreement'
      key :description, description
      key :operationId, 'getContestableIssues'
      key :tags, %w[notice_of_disagreements]

      response 200 do
        key :description, 'Issues'
        schema '$ref': :nodContestableIssues
      end

      response 404 do
        key :description, 'Veteran not found'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/supplemental_claims' do
    operation :post do
      key :tags, %w[supplemental_claims]
      key :summary, 'Creates a supplemental claim'
      key :operationId, 'createSupplementalClaim'
      description = 'Submits an appeal of type Supplemental Claim. \
      This endpoint is the same as submitting VA form 200995 via mail or fax \
      directly to the Board of Veterans’ Appeals.'
      key :description, description

      parameter do
        key :name, :request
        key :in, :body
        key :required, true
        schema '$ref': :scCreate
      end

      response 200 do
        key :description, 'Submitted'
        schema '$ref': :scShowRoot
      end

      response 422 do
        key :description, 'Malformed request'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/supplemental_claims/{uuid}' do
    operation :get do
      key :description, 'Returns all of the data associated with a specific \
      Supplemental Claim.'
      key :operationId, 'showSupplementalClaim'
      key :tags, %w[supplemental_claims]

      parameter do
        key :name, :uuid
        key :in, :path
        key :description, 'UUID of a supplemental claim'
        key :required, true
        key :type, :string
        key :format, :uuid
        key :pattern, '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      end

      response 200 do
        key :description, 'status and original payload for Supplemental Claim'
        schema '$ref': :scShowRoot
      end

      response 404 do
        key :description, 'ID not found'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/supplemental_claims/contestable_issues/{benefit_type}' do
    operation :get do
      description =
        'For the logged-in veteran, returns a list of issues that could be \
      contested in a Supplemental Claim'
      key :description, description
      key :operationId, 'getContestableIssues'
      key :tags, %w[supplemental_claims]

      parameter do
        key :name, :benefit_type
        key :in, :path
        key :required, true
        key :type, :string
        key :enum, VetsJsonSchema::SCHEMAS.fetch('SC-GET-CONTESTABLE-ISSUES-REQUEST-BENEFIT-TYPE_V1')['enum']
      end

      response 200 do
        key :description, 'Issues'
        schema '$ref': :scContestableIssues
      end

      response 404 do
        key :description, 'Veteran not found'
        schema '$ref': :Errors
      end
    end
  end

  swagger_path '/decision_reviews/v1/decision_review_evidence' do
    operation :post do
      extend Swagger::Responses::BadRequestError

      key :description, 'Uploadfile containing supporting evidence for Notice of Disagreement or Supplemental Claims'
      key :operationId, 'decisionReviewEvidence'
      key :tags, %w[notice_of_disagreements supplemental_claims]

      parameter do
        key :name, :decision_review_evidence_attachment
        key :in, :body
        key :description, 'Object containing file name'
        key :required, true

        schema do
          key :required, %i[file_data]
          property :file_data, type: :string, example: 'filename.pdf'
        end
      end

      response 200 do
        key :description, 'Response is ok'
        schema do
          key :$ref, :DecisionReviewEvidence
        end
      end
    end
  end
end
