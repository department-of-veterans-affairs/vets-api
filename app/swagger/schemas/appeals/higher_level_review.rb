# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class HigherLevelReview
        include Swagger::Blocks

        swagger_schema :HigherLevelReview do
          key :required, %i[data included]
          property :data, type: :object do
            key :required, %i[
              id
              type
              attributes
              relationships
            ]
            property :id, type: :string do
              key :format, :uuid
              key :pattern, '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$'
            end
            property :type, type: :string do
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
              property :aoj, type: :string
              property :program_area, type: :string
              property :benefit_type, type: :string do
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
              property :receipt_date, type: :string, format: :date
              property :informal_conference, type: :boolean
              property :same_office, type: :boolean
              property :legacy_opt_in_approved, type: :boolean
              property :alerts do
                key :'$ref', :HigherLevelReviewAlerts
              end
              property :events, type: :array do
                items do
                  key :type, :object
                  property :type, type: :string do
                    key :enum, %w[
                      hlr_request
                      hlr_request_event
                      hlr_decision_event
                      hlr_dta_error_event
                      dta_decision_event
                      hlr_other_close_event
                    ]
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
            property :details, type: :object do
              property :decision_date, type: :string
              property :available_options do
                key :type, :array
                items do
                  key :type, :string
                end
              end
              property :due_date do
                key :type, :string
                key :format, :date
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
          %i[request_issues decision_issues].each do |prop|
            property prop, type: :object do
              property :data, type: :array do
                items do
                  key :type, :object
                  property :type, type: :string, enum: [prop.to_s.titleize.delete(' ')[0..-2]]
                  property :id, type: :string
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
              property :option_one do
                key :type, :object
                property :type, type: :string, enum: %w[DecisionIssue]
                property :id, type: :integer
                property :attributes, type: :object do
                  property :approx_decision_date, type: :string, format: :date
                  property :decision_text, type: :string
                  property :description, type: :string
                  property :disposition, type: :string
                  property :finalized, type: :boolean
                end
              end
              property :option_two do
                key :type, :object
                property :type, type: :string, enum: %w[RequestIssue]
                property :id, type: :integer
                property :attributes, type: :object do
                  property :active, type: :boolean
                  property :status_description, type: :string
                  property :diagnostic_code, type: :string
                  property :rating_issue_id, type: :string
                  property :rating_issue_profile_date, type: :string, format: :date
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
                  property :withdrawal_date, type: :string, format: :date
                  property :contested_issue_description, type: :string
                  property :end_product_cleared, type: :boolean
                  property :end_product_code, type: :string
                end
              end
            end
          end
        end

        swagger_schema :UUID do
          key :type, :string
          key :format, :uuid
          key :pattern, "^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$"
        end

        payee_codes = []

        (0..99).each do |num|
          num.digits.count == 1 ? payee_codes.push("0#{num}") : payee_codes.push(num.to_s)
        end

        swagger_schema :PayeeCode do
          key :type, :string
          key :enum, payee_codes
        end
      end
    end
  end
end
