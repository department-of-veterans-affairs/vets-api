# frozen_string_literal: true

module Facilities
  class VBAFacility < BaseFacility
    class << self
      attr_writer :validate_on_load

      def pull_source_data
        metadata = Facilities::MetadataClient.new.get_metadata(arcgis_type)
        max_record_count = metadata['maxRecordCount']
        Facilities::Client.new.get_all_facilities(arcgis_type, sort_field, max_record_count).map(&method(:new))
      end

      def service_list
        %w[ApplyingForBenefits BurialClaimAssistance DisabilityClaimAssistance
           eBenefitsRegistrationAssistance EducationAndCareerCounseling EducationClaimAssistance
           FamilyMemberClaimAssistance HomelessAssistance VAHomeLoanAssistance Pensions
           InsuranceClaimAssistanceAndFinancialCounseling PreDischargeClaimAssistance
           IntegratedDisabilityEvaluationSystemAssistance TransitionAssistance
           VocationalRehabilitationAndEmploymentAssistance UpdatingDirectDepositInformation]
      end

      def arcgis_type
        'VBA_Facilities'
      end

      def sort_field
        'Facility_Number'
      end

      def attribute_map
        {
          'unique_id' => 'Facility_Number',
          'name' => 'Facility_Name',
          'classification' => 'Facility_Type',
          'website' => 'Website_URL',
          'phone' => { 'main' => 'Phone', 'fax' => 'Fax' },
          'physical' => { 'address_1' => 'Address_1', 'address_2' => 'Address_2',
                          'address_3' => '', 'city' => 'CITY', 'state' => 'STATE',
                          'zip' => 'Zip' },
          'hours' => BaseFacility::HOURS_STANDARD_MAP,
          'benefits' => benefits_services,
          'mapped_fields' => mapped_fields_list
        }
      end

      def benefits_services
        {
          'ApplyingForBenefits' => 'Applying_for_Benefits',
          'BurialClaimAssistance' => 'Burial_Claim_assistance',
          'DisabilityClaimAssistance' => 'Disability_Claim_assistance',
          'eBenefitsRegistrationAssistance' => 'eBenefits_Registration',
          'EducationAndCareerCounseling' => 'Education_and_Career_Counseling',
          'EducationClaimAssistance' => 'Education_Claim_Assistance',
          'FamilyMemberClaimAssistance' => 'Family_Member_Claim_Assistance',
          'HomelessAssistance' => 'Homeless_Assistance',
          'VAHomeLoanAssistance' => 'VA_Home_Loan_Assistance',
          'InsuranceClaimAssistanceAndFinancialCounseling' => 'Insurance_Claim_Assistance',
          'IntegratedDisabilityEvaluationSystemAssistance' => 'IDES',
          'PreDischargeClaimAssistance' => 'Pre_Discharge_Claim_Assistance',
          'TransitionAssistance' => 'Transition_Assistance',
          'UpdatingDirectDepositInformation' => 'Updating_Direct_Deposit_Informa',
          'VocationalRehabilitationAndEmploymentAssistance' => 'Vocational_Rehabilitation_Emplo'
        }
      end

      def mapped_fields_list
        %w[Facility_Number Facility_Name Facility_Type Website_URL Lat Long Other_Services
           Address_1 Address_2 CITY STATE Zip Phone Fax Monday Tuesday Wednesday Thursday
           Friday Saturday Sunday Applying_for_Benefits Burial_Claim_assistance
           Disability_Claim_assistance eBenefits_Registration Education_and_Career_Counseling
           Education_Claim_Assistance Family_Member_Claim_Assistance Homeless_Assistance
           VA_Home_Loan_Assistance Insurance_Claim_Assistance IDES Pre_Discharge_Claim_Assistance
           Transition_Assistance Updating_Direct_Deposit_Informa Vocational_Rehabilitation_Emplo]
      end
    end
  end
end
