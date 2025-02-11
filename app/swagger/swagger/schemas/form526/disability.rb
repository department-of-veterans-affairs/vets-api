# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class Disability
        include Swagger::Blocks

        swagger_schema :NewDisability do
          key :required, %i[condition cause]

          property :condition, type: :string
          property :cause, type: :string, enum:
            %w[
              NEW
              SECONDARY
              WORSENED
              VA
            ]
          property :classificationCode, type: :string
          property :primaryDescription, type: :string
          property :causedByDisability, type: :string
          property :causedByDisabilityDescription, type: :string
          property :specialIssues, type: :array do
            items do
              key :$ref, :SpecialIssue
            end
          end
          property :worsenedDescription, type: :string
          property :worsenedEffects, type: :string
          property :vaMistreatmentDescription, type: :string
          property :vaMistreatmentLocation, type: :string
        end

        swagger_schema :RatedDisability do
          key :required, %i[name disabilityActionType]

          property :name, type: :string
          property :disabilityActionType, type: :string, enum:
            %w[
              NONE
              NEW
              SECONDARY
              WORSENED
              VA
            ]
          property :specialIssues, type: :array do
            items do
              key :$ref, :SpecialIssue
            end
          end
          property :ratedDisabilityId, type: :string
          property :ratingDecisionId, type: :string
          property :diagnosticCode, type: :number
          property :classificationCode, type: :string
          property :secondaryDisabilities, type: :array, maxItems: 100 do
            items type: :object do
              key :required, %i[name disabilityActionType]

              property :name, type: :string
              property :disabilityActionType, type: :string, enum:
                %w[
                  NONE
                  NEW
                  SECONDARY
                  WORSENED
                  VA
                ]
              property :specialIssues, type: :array do
                items do
                  key :$ref, :SpecialIssue
                end
              end
              property :ratedDisabilityId, type: :string
              property :ratingDecisionId, type: :string
              property :diagnosticCode, type: :number
              property :classificationCode, type: :string
            end
          end
        end

        swagger_schema :SpecialIssue do
          property :items, type: :string, enum:
            [
              'ALS',
              'HEPC',
              'POW',
              'PTSD/1',
              'PTSD/2',
              'PTSD/3',
              'PTSD/4',
              'MST',
              '38 USC 1151',
              'ABA Election',
              'Abandoned VDC Claim',
              'AMC NOD Brokering Project',
              'Administrative Decision Review - Level 1',
              'Administrative Decision Review - Level 2',
              'Agent Orange - Vietnam',
              'Agent Orange - outside Vietnam or unknown',
              'AMA SOC/SSOC Opt-In',
              'Amyotrophic Lateral Sclerosis (ALS)',
              'Annual Eligibility Report',
              'Asbestos',
              'AutoEstablish',
              'Automated Drill Pay Adjustment',
              'Automated Return to Active Duty',
              'BDD – Excluded',
              'Brokered - D1BC',
              'Brokered - Internal',
              'Burn Pit Exposure',
              'C-123',
              'COWC',
              'Character of Discharge',
              'Challenge',
              'ChemBio',
              'Claimant Service Verification Accepted',
              'Combat Related Death',
              'Compensation Service Review – AO Outside RVN & Ship',
              'Compensation Service Review - Equitable Relief',
              'Compensation Service Review - Extraschedular',
              'Compensation Service Review – MG/CBRNE/Shad',
              'Compensation Service Review - Opinion',
              'Compensation Service Review - Over $25K',
              'Compensation Service Review - POW',
              'Compensation Service Review - Radiation',
              'Decision Ready Claim',
              'Decision Ready Claim - Deferred',
              'Decision Ready Claim - Partial Deferred',
              'Disability Benefits Questionnaire - Private',
              'Disability Benefits Questionnaire - VA',
              'DRC – Exam Review Complete Approved',
              'DRC – Exam Review Complete Disapproved',
              'DRC – Pending File Scan',
              'DRC – Vendor Exam Recommendation',
              'DTA Error – Exam/MO',
              'DTA Error – Fed Recs',
              'DTA Error – Other Recs',
              'DTA Error – PMRs',
              'Emergency Care – CH17 Determination',
              'Enhanced Disability Severance Pay',
              'Environmental Hazard - Camp Lejeune',
              'Environmental Hazard – Camp Lejeune – Louisville',
              'Environmental Hazard in Gulf War',
              'Extra-Schedular 3.321(b)(1)',
              'Extra-Schedular IU 4.16(b)',
              'FDC Excluded - Additional Claim Submitted',
              'FDC Excluded - All Required Items Not Submitted',
              'FDC Excluded - Appeal Pending',
              'FDC Excluded - Appeal submitted',
              'FDC Excluded - Claim Pending',
              'FDC Excluded - Claimant Declined FDC Processing',
              'FDC Excluded - Evidence Received After FDC CEST',
              'FDC Excluded - FDC Certification Incomplete',
              'FDC Excluded - FTR to Examination',
              'FDC Excluded - Necessary Form(s) not Submitted',
              'FDC Excluded - Needs Non-Fed Evidence Development',
              'FDC Excluded - requires INDPT VRFCTN of FTI',
              'Fed Record Delay - No Further Dev',
              'Force Majeure',
              'Fully Developed Claim',
              'Gulf War Presumptive',
              'HIV',
              'Hepatitis C',
              'Hospital Adjustment Action Plan FY 18/19',
              'IDES Deferral',
              'JSRRC Request',
              'Local Hearing',
              'Local Mentor Review',
              'Local Quality Review',
              'Local Quality Review IPR',
              'Medical Foster Home',
              'Military Sexual Trauma (MST)',
              'MQAS Separation and Severance Pay Audit',
              'Mustard Gas',
              'National Quality Review',
              'Nehmer AO Peripheral Neuropathy',
              'Nehmer Phase II',
              'Non-ADL Notification Letter',
              'Non-Nehmer AO Peripheral Neuropathy',
              'Non-PTSD Personal Trauma',
              'Potential Under/Overpayment',
              'POW',
              'PTSD - Combat',
              'PTSD - Non-Combat',
              'PTSD - Personal Trauma',
              'RO Special issue 1',
              'RO Special issue 2',
              'RO Special Issue 3',
              'RO Special Issue 4',
              'RO Special Issue 5',
              'RO Special Issue 6',
              'RO Special Issue 7',
              'RO Special Issue 8',
              'RO Special Issue 9',
              'RVSR Examination',
              'Radiation',
              'Radiation Radiogenic Disability Confirmed',
              'Rating Decision Review - Level 1',
              'Rating Decision Review - Level 2',
              'Ready for Exam',
              'Same Station Review',
              'SHAD',
              'Sarcoidosis',
              'Simultaneous Award Adjustment Not Permitted',
              'Specialized Records Request',
              'Stage 1 Development',
              'Stage 2 Development',
              'Stage 3 Development',
              'TBI Exam Review',
              'Temp 100 Convalescence',
              'Temp 100 Hospitalization',
              'Tobacco',
              'Tort Claim',
              'Traumatic Brain Injury',
              'Upfront Verification',
              'VACO Special issue 1',
              'VACO Special issue 2',
              'VACO Special Issue 3',
              'VACO Special Issue 4',
              'VACO Special Issue 5',
              'VACO Special Issue 6',
              'VACO Special Issue 7',
              'VACO Special Issue 8',
              'VACO Special Issue 9',
              'VASRD-Cardiovascular',
              'VASRD-Dental',
              'VASRD-Digestive',
              'VASRD-Endocrine',
              'VASRD-Eye',
              'VASRD-GU',
              'VASRD-GYN',
              'VASRD-Hemic',
              'VASRD-Infectious',
              'VASRD-Mental',
              'VASRD-Musculoskeletal',
              'VASRD-Neurological',
              'VASRD-Respiratory/Auditory',
              'VASRD-Skin',
              'Vendor Exclusion - No Diagnosis',
              'VONAPP Direct Connect',
              'WARTAC',
              'WARTAC Trainee'
            ]
        end
      end
    end
  end
end
