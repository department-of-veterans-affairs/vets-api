# frozen_string_literal: true

module Swagger
  module Schemas
    class Appeals
      include Swagger::Blocks

      swagger_schema :Appeals do
        key :required, [:data]
        property :data, type: :array
      end

      swagger_schema :HigherLevelReview do
        key :required, %i[data included]
        property :data, type: :object do
          key :required, %i[
            id
            type
            attributes
            relationships
          ]
          property :id do
            key :type, :string
            key :format, :uuid
            key :pattern, '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$'
          end
          property :type do
            key :type, :string
            key :enum, %w[HigherLevelReview]
            key :description, 'Will be "Higher Level Review"'
          end
          property :attributes, type: :object do
            key :required, %i[
              status
              program_area
              benefit_type
              description
              alerts
              events
            ]
            property :status, type: :string
            property :aoj, type: :string, 
            property :program_area, type: :string
            property :benefit_type do
              key :type, :string
              key :enum, %w[
                compensation
                pension
                fiduciary
                insurance
                education
                voc_rehab
                loan_guaranty
                vha
                nca
              ]
            end
            property :description, type: :string
            property :receipt_date do
              key :type, :string
              key :format, :date
              key :nullable, true
            end
            property :informal_conference, type: :boolean
            property :same_office, type: :boolean
            property :legacy_opt_in_approved, type: :boolean
            property :alerts do
              key :'$ref', :HigherLevelReviewAlerts
            end
            property :events do
              key :type, :array
              items do
                key :type, :object
                property :type do
                  key :'$ref', :HigherLevelReviewEvents
                end
              end
            end
          end
          property :relationships do
            key :'$ref', :HigherLevelReviewRelationships
          end
        end
        property :included do
          key :'$ref', :HigherLevelReviewIncluded
        end
      end

      swagger_schema :HigherLevelReviewAlerts do
        key :type, :array
        items do
          key :type, :object
          property :type, type: :string, enum: %w[AmaPostDecision]
          property :details do
            key :type, :object
            property :decision_date, type: :string, 
            property :available_options do
              key :type, :array
              items do
                key :type, :string
              end
            end
            property :due_date do
              key :type, :string
              key :format, :date
              key :nullable, true
            end
          end
        end
      end

      swagger_schema :HigherLevelReviewRelationships do
        key :type, :object
        property :veteran, type: :object do
          property :data, type: :object do
            property :type, type: :string, enum: %w[Veteran]
            property :id, type: :string
          end
        end
        property :claimaint, type: :object do
          property :data, type: :object do
            property :type, type: :string, enum: %w[Claimant]
          end
        end
        %i[requestIssues decisionIssues].each do |prop|
          property prop, type: :object do
            property :data, type: :array do
              items do
                key :type, :object
                property :type, type: :string, enum: [prop.to_s.titleize.delete(' ')[0..-2]]
                property :id, type: :integer
              end
            end
          end
        end
      end

      swagger_schema :HigherLevelReviewEvents do
        key :type, :array
        items do
          key :type, :object
          property :type do
            key :type, :string
            key :enum, %w[
              hlr_request_event
              hlr_decision_event
              hlr_dta_error_event
              dta_decision_event
              hlr_other_close_event
            ]
          end
          property :date, type: :string, format: :date
        end
      end

      swagger_schema :HigherLevelReviewIncluded do
        key :type, :array
        items do
          property :anyOf do
            property :optionOne do
              key :type, :object
              property :type, type: :string, enum: %w[DecisionIssue]
              property :id, type: :integer
              property :attributes, type: :object do
                property :approxDecisionDate, type: :string, format: :date
                property :decisionText, type: :string
                property :description, type: :string
                property :disposition, type: :string
                property :finalized, type: :boolean
              end
            end
            property :optionTwo do
              key :type, :object
              property :type, type: :string, enum: %w[RequestIssue]
              property :id, type: :integer
              property :attributes, type: :object do
                property :active, type: :boolean
                property :statusDescription, type: :string
                property :diagnosticCode, type: :string
                property :ratingIssueId, type: :string
                property :ratingIssueProfileDate, type: :string do
                  key :format, :date
                  key :nullable, true
                end
                property :rating_decision_reference_id, type: :string
                property :description, type: :string
                property :contention_text, type: :string
                property :approx_decision_date, type: :string, format: :date
                property :category, type: :string
                property :notes, type: :string
                property :is_unidentified, type: :boolean
                property :ramp_claim_id, type: :string
                property :legacy_appeal_id, type: :string
                property :legacy_appeal_issue_id, type: :string
                property :ineligible_reason, type: :string
                property :ineligible_due_to_id, type: :integer
                property :decision_review_title, type: :string
                property :title_of_active_review, type: :string
                property :decision_issue_id, type: :integer
                property :withdrawal_date, type: :string do
                  key :format, :date
                  key :nullable, true
                end
                property :contested_issue_description, type: :string
                property :end_product_cleared, type: :boolean
                property :end_product_code, type: :string
              end
            end
          end
        end
      end

      swagger_schema :IntakeStatus do
        key :type, :object
        key :description, 'An accepted Decision Review still needs to be processed '\
                          'before the Decision Review can be accessed'
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string, description: 'Will be Intake Status'
          property :attributes, type: :object do
            property :status, type: :string do
              key :enum, %w[
                processed
                canceled
                attempted
                submitted
                not_yet_submitted
              ]
              key :description, '`not_yet_submitted` - The DecisionReview has not been submitted yet.
                                `submitted` - The DecisionReview is in the queue to be attempted.
                                `attempted` - Processing of the DecisionReview is being attempted.
                                `canceled` - The DecisionReview has been successfully canceled.
                                `processed` - The DecisionReview has been processed and transmitted '\
                                'to the appropriate government agency.'
            end
          end
        end
      end

      swagger_schema :UUID do
        key :type, :string
        key :format, :uuid
        key :pattern, "^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$"
      end

      swagger_schema :AppealsErrors do
        key :type, :object
        items do
          key :type, :object
          property :title, type: :string
          property :detail, type: :string
        end
      end
    end
  end
end
