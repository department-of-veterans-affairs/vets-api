# frozen_string_literal: true

require 'claims_api/poa_pdf_constructor/base'
require 'claims_api/poa_pdf_constructor/signature'

module ClaimsApi
  module PoaPdfConstructor
    class Organization < ClaimsApi::PoaPdfConstructor::Base
      protected

      def page1_template_path
        Rails.root.join('modules', 'claims_api', 'config', 'pdf_templates', '21-22', '1.pdf')
      end

      def page2_template_path
        Rails.root.join('modules', 'claims_api', 'config', 'pdf_templates', '21-22', '2.pdf')
      end

      def page1_signatures(_signatures)
        []
      end

      def page2_signatures(signatures)
        [
          ClaimsApi::PoaPdfConstructor::Signature.new(data: signatures['veteran'], x: 35, y: 263),
          ClaimsApi::PoaPdfConstructor::Signature.new(data: signatures['representative'], x: 35, y: 216)
        ]
      end

      # rubocop:disable Layout/LineLength
      def page2_options(data)
        base_form = 'F[0].Page_2[0]'
        {
          "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[0]": data.dig('veteran', 'ssn')[0..2],
          "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[0]": data.dig('veteran', 'ssn')[3..4],
          "#{base_form}.SocialSecurityNumber_LastFourNumbers[0]": data.dig('veteran', 'ssn')[5..8],
          "#{base_form}.I_Authorize[1]": data['recordConcent'] == true ? 1 : 0,
          "#{base_form}.Drug_Abuse[0]": data['consentLimits'].present? && data['consentLimits'].include?('DRUG ABUSE') ? 1 : 0,
          "#{base_form}.Alcoholism_Or_Alcohol_Abuse[0]": data['consentLimits'].present? && data['consentLimits'].include?('ALCOHOLISM') ? 1 : 0,
          "#{base_form}.Infection_With_The_Human_Immunodeficiency_Virus_HIV[0]": data['consentLimits'].present? && data['consentLimits'].include?('HIV') ? 1 : 0,
          "#{base_form}.sicklecellanemia[0]": data['consentLimits'].present? && data['consentLimits'].include?('SICKLE CELL') ? 1 : 0,
          "#{base_form}.I_Authorize[0]": data['consentAddressChange'] == true ? 1 : 0,
          "#{base_form}.Date_Signed[0]": I18n.l(Time.zone.now.to_date, format: :va_form),
          "#{base_form}.Date_Signed[1]": I18n.l(Time.zone.now.to_date, format: :va_form)
        }
      end

      # rubocop:disable Metrics/MethodLength
      def page1_options(data)
        base_form = 'F[0].Page_1[0]'
        {
          # Veteran
          "#{base_form}.VeteransLastName[0]": data.dig('veteran', 'lastName'),
          "#{base_form}.VeteransFirstName[0]": data.dig('veteran', 'firstName'),
          "#{base_form}.TelephoneNumber_IncludeAreaCode[1]": "#{data.dig('veteran', 'phone', 'areaCode')} #{data.dig('veteran', 'phone', 'phoneNumber')}",
          "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[0]": data.dig('veteran', 'ssn')[0..2],
          "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[0]": data.dig('veteran', 'ssn')[3..4],
          "#{base_form}.SocialSecurityNumber_LastFourNumbers[0]": data.dig('veteran', 'ssn')[5..8],
          "#{base_form}.DOBmonth[0]": data.dig('veteran', 'birthdate').split('-').second,
          "#{base_form}.DOBday[0]": data.dig('veteran', 'birthdate').split('-').last.first(2),
          "#{base_form}.DOByear[0]": data.dig('veteran', 'birthdate').split('-').first,
          "#{base_form}.Veterans_MailingAddress_NumberAndStreet[0]": data.dig('veteran', 'address', 'numberAndStreet'),
          "#{base_form}.MailingAddress_ApartmentOrUnitNumber[1]": data.dig('veteran', 'address', 'aptUnitNumber'),
          "#{base_form}.Claimants_MailingAddress_City[1]": data.dig('veteran', 'address', 'city'),
          "#{base_form}.Claimants_MailingAddress_StateOrProvince[1]": data.dig('veteran', 'address', 'state'),
          "#{base_form}.Claimants_MailingAddress_Country[1]": data.dig('veteran', 'address', 'country'),
          "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.dig('veteran', 'address', 'zipFirstFive'),
          "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[1]": data.dig('veteran', 'address', 'zipLastFour'),

          # Claimant
          "#{base_form}.Claimants_FirstName[0]": data.dig('claimant', 'firstName'),
          "#{base_form}.Claimants_LastName[0]": data.dig('claimant', 'lastName'),
          "#{base_form}.Claimants_MiddleInitial1[0]": data.dig('claimant', 'middleInitial'),
          "#{base_form}.Claimants_MailingAddress_NumberAndStreet[0]": data.dig('claimant', 'address', 'numberAndStreet'),
          "#{base_form}.Claimants_MailingAddress_ApartmentOrUnitNumber[0]": data.dig('claimant', 'address', 'aptUnitNumber'),
          "#{base_form}.Claimants_MailingAddress_City[0]": data.dig('claimant', 'address', 'city'),
          "#{base_form}.Claimants_MailingAddress_StateOrProvince[0]": data.dig('claimant', 'address', 'state'),
          "#{base_form}.Claimants_MailingAddress_Country[0]": data.dig('claimant', 'address', 'country'),
          "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.dig('claimant', 'address', 'zipFirstFive'),
          "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.dig('address', 'zipLastFour'),
          "#{base_form}.TelephoneNumber_IncludeAreaCode[0]": "#{data.dig('claimant', 'phone', 'areaCode')} #{data.dig('claimant', 'phone', 'phoneNumber')}",
          "#{base_form}.Claimants_EmailAddress_Optional[0]": data.dig('claimant', 'email'),
          "#{base_form}.Relationship_To_Veteran[0]": data.dig('claimant', 'relationship'),

          "#{base_form}.Name_Of_Service_Organization[0]": data.dig('serviceOrganization', 'organizationName'),
          "#{base_form}.Name_Of_Official_Representative[0]": "#{data.dig('serviceOrganization', 'firstName')} #{data.dig('serviceOrganization', 'lastName')}",

          "#{base_form}.Date_Of_This_Appointment[0]": I18n.l(Time.zone.now.to_date, format: :va_form)
        }
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Layout/LineLength
    end
  end
end
