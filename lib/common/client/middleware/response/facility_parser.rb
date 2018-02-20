# frozen_string_literal: true

require 'facility_access'

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
            mapping.slice('unique_id', 'name', 'classification', 'website').each do |key, value|
              mapped_attrs[key] = attrs[value]
            end
            mapped_attrs['phone'] = nested(mapping['phone'], attrs)
            mapped_attrs['address']['physical'] = nested(mapping['physical'], attrs)
            mapped_attrs['address']['mailing'] = nested(mapping['mailing'], attrs)
            mapped_attrs['hours'] = nested(mapping['hours'], attrs)
            mapped_attrs['access'] = nested(mapping['access'], attrs)
            mapped_attrs['feedback'] = nested(mapping['feedback'], attrs)
            mapped_attrs['services']['benefits'] = nested(mapping['benefits'], attrs)
            mapped_attrs.merge!(
              'lat' => entry['geometry']['x'],
              'long' => entry['geometry']['y']
            )
          end

          def nested(item, attrs)
            return unless item
            item.each_with_object({}) do |(key, value), hash|
              hash[key] = value.respond_to?(:call) ? value.call(attrs) : attrs[value]
            end
          end

          def self.mh_clinic_phone(attrs)
            val = attrs['MHClinicPhone']
            val = attrs['MHPhone'] if val.blank?
            return '' if val.blank?
            result = val.to_s
            result << ' x ' + attrs['Extension'].to_s unless
              (attrs['Extension']).blank? || (attrs['Extension']).zero?
            result
          end

          def self.to_date(dtstring)
            Date.iso8601(dtstring).iso8601
          end

          def self.satisfaction_data(attrs)
            result = {}
            datum = FacilitySatisfaction.find(attrs['StationNumber'].upcase)
            if datum.present?
              datum.metrics.each { |k, v| result[k.to_s] = v.present? ? v.round(2) : nil }
              result['effective_date'] = to_date(datum.source_updated)
            end
            result
          end

          def self.wait_time_data(attrs)
            result = {}
            datum = FacilityWaitTime.find(attrs['StationNumber'].upcase)
            if datum.present?
              datum.metrics.each { |k, v| result[k.to_s] = v }
              result['effective_date'] = to_date(datum.source_updated)
            end
            result
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
                         'pharmacy' => 'PharmacyPhone', 'mental_health_clinic' => method(:mh_clinic_phone) },
            'physical' => { 'address_1' => 'Street', 'address_2' => 'Building',
                            'address_3' => 'Suite', 'city' => 'City', 'state' => 'State',
                            'zip' => 'Zip' },
            'hours' => { 'Monday' => '', 'Tuesday' => '',
                         'Wednesday' => '', 'Thursday' => '',
                         'Friday' => '', 'Saturday' => '',
                         'Sunday' => '' },
            'access' => { 'health' => method(:wait_time_data) },
            'feedback' => { 'health' => method(:satisfaction_data) },
            'services' => {
              'Audiology' => [],
              'ComplementaryAlternativeMed' => [],
              'DentalServices' => [],
              'DiagnosticServices' => %w[
                ImagingAndRadiology LabServices
              ],
              'EmergencyDept' => [],
              'EyeCare' => [],
              'MentalHealthCare' => %w[
                OutpatientMHCare OutpatientSpecMHCare VocationalAssistance
              ],
              'OutpatientMedicalSpecialty' => %w[
                AllergyAndImmunology CardiologyCareServices DermatologyCareServices
                Diabetes Dialysis Endocrinology Gastroenterology
                Hematology InfectiousDisease InternalMedicine
                Nephrology Neurology Oncology
                PulmonaryRespiratoryDisease Rheumatology SleepMedicine
              ],
              'OutpatientSurgicalSpecialty' => %w[
                CardiacSurgery ColoRectalSurgery ENT GeneralSurgery
                Gynecology Neurosurgery Orthopedics PainManagement
                PlasticSurgery Podiatry ThoracicSurgery Urology
                VascularSurgery
              ],
              'PrimaryCare' => [],
              'Rehabilitation' => [],
              'UrgentCare' => [],
              'WellnessAndPreventativeCare' => []
            }
          }.freeze
        end
      end
    end
  end
end

Faraday::Response.register_middleware facility_parser: Common::Client::Middleware::Response::FacilityParser
