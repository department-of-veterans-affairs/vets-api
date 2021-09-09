# frozen_string_literal: true

require 'decision_review/schemas'

class Swagger::V1::Requests::Appeals::Appeals
  include Swagger::Blocks

  swagger_path '/v1/higher_level_reviews' do
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

  swagger_path '/v1/higher_level_reviews/{uuid}' do
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
        key :pattern, "^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$"
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

  swagger_path '/v1/higher_level_reviews/contestable_issues/{benefit_type}' do
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
        key :enum, VetsJsonSchema::SCHEMAS.fetch('HLR-GET-CONTESTABLE-ISSUES-REQUEST-BENEFIT-TYPE')['enum']
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
end
