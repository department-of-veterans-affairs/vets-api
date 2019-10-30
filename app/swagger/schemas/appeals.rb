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
              aoj
              program_area
              benefit_type
              description
              receipt_date
              informal_conference
              same_office
              legacy_opt_in_approved
              alerts
              events
            ]
            property :status, type: :string
            property :aoj, type: :string, nullable: true
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
            property :informal_conference, type: :boolean, nullable: true
            property :same_office, type: :boolean, nullable: true
            property :legacy_opt_in_approved, type: :boolean, nullable: true
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

      swagger_schema :HigherLevelReviewParameters do
        key :type, :object
        key :required, %i[data]
        property :data, type: :object do
          key :required, %i[type attributes relationships]
          property :type, type: :string, enum: %w[HigherLevelReview]
          property :attributes, type: :object do
            key :required, %i[
              receipt_date
              informal_conference
              same_office
              legacy_opt_in_approved
              benefit_type
            ]
            property :receipt_date, type: :string, format: :date
            property :informal_conference, type: :boolean
            property :same_office, type: :boolean
            property :legacy_opt_in_approved, type: :boolean
            property :benefit_type do
              key :'$ref', :BenefitType
            end
          end
          property :relationships, type: :object do
            key :required, %i[veteran]
            property :veteran, type: :object do
              key :required, %i[data]
              property :data, type: :object do
                key :required, %i[type id]
                property :type, type: :string, enum: %w[Veteran]
                property :id, type: :string
              end
            end
            property :claimaint, type: :object do
              key :required, %i[data]
              property :data, type: :object do
                key :required, %i[type id meta]
                property :type, type: :string, enum: %w[Claimaint]
                property :id, type: :string
                property :meta, type: :object do
                  key :required, %i[payee_code]
                  property :payee_code do
                    key :'$ref', :PayeeCode
                  end
                end
              end
            end
          end
        end
        property :included, type: :array do
          items do
            key :type, :object
            key :required, %i[type attributes]
            property :type, type: :string, enum: %w[request_issue]
            property :attributes, type: :object do
              property :notes, type: :string
              property :decision_issue_id, type: :integer
              property :rating_issue_id, type: :string
              property :legacy_appeal_id, type: :string
              property :legacy_appeal_issue_id, type: :integer
              property :category do
                key :'$ref', :NonratingIssueCategory
              end
              property :decision_date, type: :string
              property :decision_text, type: :string
            end
          end
        end
      end

      swagger_schema :HigherLevelReviewAlerts do
        key :type, :array
        items do
          key :type, :object
          property :type, type: :string, enum: %w[AmaPostDecision]
          property :details do
            key :type, :object
            property :decision_date, type: :string, nullable: true
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
                property :approxDecisionDate, type: :string, format: :date, nullable: true
                property :decisionText, type: :string, nullable: true
                property :description, type: :string
                property :disposition, type: :string, nullable: true
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
                property :diagnosticCode, type: :string, nullable: true
                property :ratingIssueId, type: :string, nullable: true
                property :ratingIssueProfileDate, type: :string do
                  key :format, :date
                  key :nullable, true
                end
                property :rating_decision_reference_id, type: :string, nullable: true
                property :description, type: :string, nullable: true
                property :contention_text, type: :string
                property :approx_decision_date, type: :string, format: :date
                property :category, type: :string, nullable: true
                property :notes, type: :string, nullable: true
                property :is_unidentified, type: :boolean, nullable: true
                property :ramp_claim_id, type: :string, nullable: true
                property :legacy_appeal_id, type: :string, nullable: true
                property :legacy_appeal_issue_id, type: :string, nullable: true
                property :ineligible_reason, type: :string, nullable: true
                property :ineligible_due_to_id, type: :integer, nullable: true
                property :decision_review_title, type: :string, nullable: true
                property :title_of_active_review, type: :string, nullable: true
                property :decision_issue_id, type: :integer, nullable: true
                property :withdrawal_date, type: :string do
                  key :format, :date
                  key :nullable, true
                end
                property :contested_issue_description, type: :string, nullable: true
                property :end_product_cleared, type: :boolean, nullable: true
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

      swagger_schema :BenefitType do
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

      swagger_schema :NonratingIssueCategory do
        key :type, :string
        key :enum, [
          "Unknown issue category",
          "Apportionment",
          "Incarceration Adjustments",
          "Audit Error Worksheet (DFAS)",
          "Active Duty Adjustments",
          "Drill Pay Adjustments",
          "Character of discharge determinations",
          "Income/net worth (pension)",
          "Dependent child - Adopted",
          "Dependent child - Stepchild",
          "Dependent child - Biological",
          "Dependency Spouse - Common law marriage",
          "Dependency Spouse - Inference of marriage",
          "Dependency Spouse - Deemed valid marriage",
          "Military Retired Pay",
          "Contested Claims (other than apportionment)",
          "Lack of Qualifying Service",
          "Other non-rated",
          "Eligibility | Wartime service",
          "Eligibility | Veteran Status",
          "Income/Net Worth | Countable Income",
          "Income/Net Worth | Residential Lot Size",
          "Income/Net Worth | Medical Expense Deductions",
          "Effective date | Liberalizing Legislation",
          "Effective date | 3.400(b)(ii)(B)",
          "Dependent Eligibility | Adoption",
          "Dependent Eligibility | Stepchild",
          "Dependent Eligibility | School child",
          "Dependent Eligibility | Validity of marriage",
          "Dependent Eligibility | Parent(s)",
          "Dependent Eligibility | Other",
          "Penalty Period",
          "Post Award Audit",
          "Overpayment | Validity of debt",
          "Overpayment | Waiver",
          "Apportionment",
          "Survivors pension eligibility",
          "Burial Benefits - NSC Burial",
          "Burial Benefits - Plot or Interment Allowance",
          "Burial Benefits - Transportation Allowance",
          "Burial Benefits - VA Hospitalization Death",
          "Appointment of a Fiduciary (38 CFR 13.100)",
          "Removal of a Fiduciary (38 CFR 13.500)",
          "Misuse Determination (38 CFR 13.400)",
          "RO Director Reconsideration of Misuse Determination (13.400(d))",
          "P&F Director's Negligence Determination for Benefits Reissuance (13.410)",
          "Basic Eligibility",
          "Entitlement to Services",
          "Plan/Goal Selection",
          "Equipment/Supply Purchases",
          "Additional Training",
          "Change of Program",
          "Feasibility to Pursue a Vocational Goal",
          "Training Facility Selection",
          "Subsistence Allowance",
          "Employment Adjustment Allowance",
          "Entitlement Extension",
          "Advance from the Revolving Fund Loan",
          "Retroactive Induction",
          "Retroactive Reimbursement",
          "Successful Closure of Case",
          "Discontinue Services",
          "Interruption of Services",
          "Accrued",
          "Eligibility | 38 U.S.C. ch. 30",
          "Eligibility | 38 U.S.C. ch. 35",
          "Eligibility | 38 U.S.C. ch. 32",
          "Eligibility | 38 U.S.C. ch. 33",
          "Eligibility | 38 U.S.C. ch. 1606",
          "Entitlement | 38 U.S.C. ch. 30",
          "Entitlement | 38 U.S.C. ch. 35",
          "Entitlement | 38 U.S.C. ch. 32",
          "Entitlement | 38 U.S.C. ch. 33",
          "Entitlement | 38 U.S.C. ch. 1606",
          "Effective Date of Award | 38 U.S.C. ch. 35",
          "Payment | 38 U.S.C. ch. 30",
          "Payment | 38 U.S.C. ch. 35",
          "Payment | 38 U.S.C. ch. 32",
          "Payment | 38 U.S.C. ch. 33",
          "Payment | 38 U.S.C. ch. 1606",
          "Overpayment | Validity of debt",
          "Vet Tec",
          "Delimiting Date Issues | 38 U.S.C. ch. 30",
          "Delimiting Date Issues | 38 U.S.C. ch. 35",
          "Delimiting Date Issues | 38 U.S.C. ch. 32",
          "Delimiting Date Issues | 38 U.S.C. ch. 33",
          "Delimiting Date Issues | 38 U.S.C. ch. 1606",
          "Other",
          "Waiver of premiums (1912-1914) | Date of total disability",
          "Waiver of premiums (1912-1914) | Effective date",
          "Waiver of premiums (1912-1914) | TDIP (1915)",
          "Waiver of premiums (1912-1914) | Other",
          "Reinstatement | Medically Qualified",
          "Reinstatement | Other",
          "RH (1922(a) S-DVI) | Timely application",
          "RH (1922(a) S-DVI) | Medically qualified",
          "RH (1922(a) S-DVI) | Discharged before 4/25/51",
          "RH (1922(a) S-DVI) | Other",
          "SRH (1922(b) S-DVI) | Timely application",
          "SRH (1922(b) S-DVI) | Over age 65",
          "SRH (1922(b) S-DVI) | Other",
          "VMLI (2106) | LOC/Reverse Mortgage",
          "VMLI (2106) | Over age 70",
          "VMLI (2106) | Death Award",
          "VMLI (2106) | Other",
          "Contested death claim | Relationships",
          "Contested death claim | Testamentary capacity",
          "Contested death claim | Undue influence",
          "Contested death claim | Intent of insured",
          "Contested death claim | Other",
          "Other",
          "Basic eligibility - Certificate of Eligibility (COE) was denied for use of benefit",
          "Validity of debt - Existing debt indicated from loan termination is incorrect as stated",
          "Waiver of indebtedness - Existing debt should be waived to allow issuance of COE",
          "Restoration of entitlement - Remove a previous loan that was paid-in-full to allow all available entitlement on the COE",
          "Other",
          "Entitlement | Reserves/National Guard",
          "Entitlement | Less than 24 months",
          "Entitlement | Character of service",
          "Entitlement | Merchant Marine",
          "Entitlement | No military information",
          "Entitlement | Cadet (service academies)",
          "Entitlement | Unmarried Adult Child",
          "Entitlement | Allied forces and non-citizens",
          "Entitlement | Pre-need",
          "Entitlement | Spouse/Surving Spouse",
          "Entitlement | Non-qualifying service",
          "Entitlement | ABMC/overseas burial",
          "Entitlement | Pre-WWI/burial site unknown",
          "Entitlement | Marked grave (death prior to 10-18-78)",
          "Entitlement | Marked grave (death on/after 10-18-78 to 10-31-90)",
          "Entitlement | Other",
          "Entitlement | Voided Enlistment",
          "Entitlement | Benefit Already Provided",
          "Entitlement | Confederate IMO",
          "Entitlement | Cremains not interred",
          "Entitlement | Historic marker deemed serviceable",
          "Entitlement | Medallion (no grave)",
          "Entitlement | Medallion (unmarked grave)",
          "Entitlement | Parent",
          "Entitlement | Replacement",
          "Entitlement | Unauthorized applicant",
          "Entitlement | Hmong",
          "Entitlement | Medallion (monetary allowance)",
          "Entitlement | IMO in NC",
          "Eligibility for Treatment | Dental",
          "Eligibility for Treatment | Other",
          "Beneficiary Travel | Mileage",
          "Beneficiary Travel | Common Carrier",
          "Beneficiary Travel | Special Mode",
          "Eligibility for Fee Basis Care",
          "Indebtedness | Validity of Debt",
          "Indebtedness | Waiver",
          "Level of Priority for Treatment",
          "Clothing Allowance § 3.810(b) Certification",
          "Prosthetics Services",
          "Family Member Services | CHAMPVA Eligibility",
          "Family Member Services | CHAMPVA Medical Charges",
          "Family Member Services | Foreign Medical Program Medical Charges",
          "Family Member Services | Spina Bifida Medical Charges",
          "Family Member Services | Camp Lejeune Family Member Eligibility",
          "Other"
        ]
      end

      swagger_schema :PayeeCode do
        key :type, :string
        key :enum, generate_int_enum(0, 99)
      end

      private

      def generate_int_enum(lower_bound, upper_bound)
        arr = []
        (lower_bound..upper_bound).each do |int|
          int = int.to_s
          int = "0#{int}" if int.length == 1
          arr.push(int)
        end
        arr
      end
    end
  end
end
