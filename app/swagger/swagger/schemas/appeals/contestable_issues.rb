# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class ContestableIssues
        include Swagger::Blocks

        swagger_schema :ContestableIssues, type: :object do
          property :data, type: :array do
            items type: :object do
              key :description, 'A contestable issue (to contest this, you include it as a RequestIssue'\
                                ' when creating a HigherLevelReview, SupplementalClaim, or Appeal)'
              property :type, type: :string, enum: %w[ContestableIssue]
              property :attributes, type: :object do
                property :ratingIssueId do
                  key :type, :string
                  key :description, 'RatingIssue ID'
                end
                property :ratingIssueProfileDate do
                  key :type, :string
                  key :format, :date
                  key :description, '(yyyy-mm-dd) RatingIssue profile date'
                end
                property :ratingIssueDiagnosticCode do
                  key :type, :string
                  key :format, :date
                  key :description, 'RatingIssue diagnostic code'
                end
                property :ratingDecisionId do
                  key :type, :string
                  key :description, 'The BGS ID for the contested rating decision.'\
                                    ' This may be populated while ratingIssueId is nil'
                end
                property :decisionIssueId do
                  key :type, :integer
                  key :description, 'DecisionIssue ID'
                end
                property :approxDecisionDate do
                  key :type, :string
                  key :format, :date
                  key :description, '(yyyy-mm-dd) Approximate decision date'
                end
                property :description do
                  key :type, :string
                  key :description, 'Description'
                end
                property :rampClaimId do
                  key :type, :string
                  key :description, 'RampClaim ID'
                end
                property :titleOfActiveReview do
                  key :type, :string
                  key :description, 'Title of DecisionReview that this issue is still active on'
                end
                property :sourceReviewType do
                  key :type, :string
                  key :description, 'The type of DecisionReview (HigherLevelReview, SupplementalClaim,'\
                                    ' Appeal) the issue was last decided on (if any)'
                end
                property :timely do
                  key :type, :boolean
                  key :description, 'An issue is timely if the receipt date is within 372 dates of the decision date.'
                end
                property :latestIssuesInChain do
                  key :type, :array
                  key :description, 'Shows the chain of decision and rating issues that preceded this issue.'\
                                    ' Only the most recent issue can be contested (the object itself that'\
                                    ' contains the latestIssuesInChain attribute).'
                  items do
                    key :type, :object
                    property :id, type: :string
                    property :approxDecisionDate do
                      key :type, :string
                      key :format, :date
                    end
                  end
                end
                property :isRating do
                  key :type, :boolean
                  key :description, 'Whether or not this is a RatingIssue'
                end
              end
            end
          end
        end
      end
    end
  end
end
