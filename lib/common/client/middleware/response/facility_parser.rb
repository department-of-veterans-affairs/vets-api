# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class FacilityParser < Faraday::Response::Middleware
          def on_complete(env)
            env.body = parse_body(env)
          end

          private

          def parse_body(env)
            json_body = Oj.load(env.body)
            case env.url.path
            when %r{\/NCA_Facilities\/}
              json_body['features'].map { |loc| attribute_mappings(loc, NCA_MAP) }
            when %r{\/VBA_Facilities\/}
              json_body['features'].map { |loc| attribute_mappings(loc, VBA_MAP) }
            when %r{\/VHA_VetCenters\/}
              json_body['features'].map { |loc| attribute_mappings(loc, VC_MAP) }
            when %r{\/VHA_Facilities\/}
              json_body['features'].map { |loc| attribute_mappings(loc, VHA_MAP) }
            else
              Common::Client::Errors::Serialization
            end
          end

          def attribute_mappings(entry, mapping)
            attrs = entry['attributes']
            mapped_attrs = { 'address' => {}, 'services' => {} }
            mapping.slice('unique_id', 'name', 'classification', 'website')
                   .each { |key, value| mapped_attrs[key] = attrs[value] }
            mapped_attrs['phone'] = nested_attributes(mapping['phone'], attrs)
            mapped_attrs['address']['physical'] = nested_attributes(mapping['physical'], attrs)
            mapped_attrs['address']['mailing'] = nested_attributes(mapping['mailing'], attrs) if mapping['mailing']
            mapped_attrs['hours'] = nested_attributes(mapping['hours'], attrs)
            mapped_attrs['services']['benefits'] = nested_attributes(mapping['benefits'], attrs) if mapping['benefits']
            mapped_attrs.merge!(
              'lat' => entry['geometry']['x'],
              'long' => entry['geometry']['y']
            )
          end

          def nested_attributes(item, attrs)
            item.each_with_object({}) do |(key, value), hash|
              hash[key] = attrs[value]
            end
          end

          NCA_MAP = {
            'unique_id' => 'SITE_ID',
            'name' => 'FULL_NAME',
            'classification' => 'SITE_TYPE',
            'website' => 'Website_URL',
            'phone' => { 'main' => 'PHONE', 'fax' => 'FAX' },
            'physical' => { 'address_1' => 'SITE_ADDRESS1', 'address_2' => 'SITE_ADDRESS2',
                            'address_3' => '', 'city' => 'SITE_CITY', 'state' => 'SITE_STATE',
                            'zip' => 'SITE_ZIP' },
            'mailing' => { 'address_1' => 'MAIL_ADDRESS1', 'address_2' => 'MAIL_ADDRESS2',
                           'address_3' => '', 'city' => 'MAIL_CITY', 'state' => 'MAIL_STATE',
                           'zip' => 'MAIL_ZIP' },
            'hours' => { 'Monday' => 'VISITATION_HOURS_WEEKDAY', 'Tuesday' => 'VISITATION_HOURS_WEEKDAY',
                         'Wednesday' => 'VISITATION_HOURS_WEEKDAY', 'Thursday' => 'VISITATION_HOURS_WEEKDAY',
                         'Friday' => 'VISITATION_HOURS_WEEKDAY', 'Saturday' => 'VISITATION_HOURS_WEEKEND',
                         'Sunday' => 'VISITATION_HOURS_WEEKEND' }
          }.freeze
          VBA_MAP = {
            'unique_id' => 'Facility_Number',
            'name' => 'Facility_Name',
            'classification' => 'Facility_Type',
            'website' => 'Website_URL',
            'phone' => { 'main' => 'Phone', 'fax' => 'Fax' },
            'physical' => { 'address_1' => 'Address_1', 'address_2' => 'Address_2',
                            'address_3' => '', 'city' => 'City', 'state' => 'State',
                            'zip' => 'Zip' },
            'hours' => { 'Monday' => '', 'Tuesday' => '',
                         'Wednesday' => '', 'Thursday' => '',
                         'Friday' => '', 'Saturday' => '',
                         'Sunday' => '' },
            'benefits' => {
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
          }.freeze

          VC_MAP = {
            'unique_id' => 'stationno',
            'name' => 'stationname',
            'classification' => 'vet_center',
            'phone' => { 'main' => 'sta_phone' },
            'physical' => { 'address_1' => 'address2', 'address_2' => 'address3',
                            'address_3' => '', 'city' => 'city', 'state' => 'st',
                            'zip' => 'zip' },
            'hours' => { 'Monday' => '', 'Tuesday' => '',
                         'Wednesday' => '', 'Thursday' => '',
                         'Friday' => '', 'Saturday' => '',
                         'Sunday' => '' }
          }.freeze

          # TODO: service heirarchy
          VHA_MAP = {
            'unique_id' => 'StationNumber',
            'name' => 'StationName',
            'classification' => 'CocClassification',
            'website' => 'Website_URL',
            'phone' => { 'main' => 'MainPhone', 'fax' => 'MainFax',
                         'after_hours' => 'AfterHoursPhone',
                         'patient_advocate' => 'PatientAdvocatePhone',
                         'enrollment_coordinator' => 'EnrollmentCoordinatorPhone',
                         'pharmacy' => 'PharmacyPhone' },
            'physical' => { 'address_1' => 'Street', 'address_2' => 'Building',
                            'address_3' => 'Suite', 'city' => 'City', 'state' => 'State',
                            'zip' => 'Zip' },
            'hours' => { 'Monday' => '', 'Tuesday' => '',
                         'Wednesday' => '', 'Thursday' => '',
                         'Friday' => '', 'Saturday' => '',
                         'Sunday' => '' }
          }.freeze
        end
      end
    end
  end
end

Faraday::Response.register_middleware facility_parser: Common::Client::Middleware::Response::FacilityParser
