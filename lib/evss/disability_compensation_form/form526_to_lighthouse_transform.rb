# frozen_string_literal: true

require 'disability_compensation/requests/form526_request_body'

module EVSS
  module DisabilityCompensationForm
    class Form526ToLighthouseTransform
      # takes known EVSS Form526Submission format and converts it to a Lighthouse request body
      # evss_data will look like JSON.parse(form526_submission.form_data)
      def transform(evss_data)
        form526 = evss_data['form526']
        lh_request_body = Requests::Form526.new
        lh_request_body.claimant_certification = true
        lh_request_body.claim_date = form526['claimDate'] if form526['claimDate']
        lh_request_body.claim_process_type = evss_claims_process_type(form526) # basic_info[:claim_process_type]

        veteran = form526['veteran']
        lh_request_body.veteran_identification = transform_veteran(veteran)
        lh_request_body.change_of_address = transform_change_of_address(veteran)
        lh_request_body.homeless = transform_homeless(veteran)

        lh_request_body
      end

      # returns "STANDARD_CLAIM_PROCESS", "BDD_PROGRAM", or "FDC_PROGRAM"
      # based off of a few attributes in the evss data
      def evss_claims_process_type(form526)
        if form526['bddQualified']
          return 'BDD_PROGRAM'
        elsif form526['standardClaim']
          return 'STANDARD_CLAIM_PROCESS'
        end

        'FDC_PROGRAM'
      end

      def transform_veteran(veteran)
        veteran_identification = Requests::VeteranIdentification.new
        veteran_identification.currently_va_employee = veteran['currentlyVAEmployee']
        veteran_identification.service_number = veteran['serviceNumber']
        veteran_identification.email_address = Requests::EmailAddress.new
        veteran_identification.email_address.email = veteran['emailAddress']
        veteran_identification.veteran_number = Requests::VeteranNumber.new
        veteran_identification.veteran_number.telephone = veteran['daytimePhone']['areaCode'] +
                                                          veteran['daytimePhone']['phoneNumber']
        transform_mailing_address(veteran, veteran_identification)

        veteran_identification
      end

      def transform_change_of_address(veteran)
        change_of_address = Requests::ChangeOfAddress.new
        change_of_address_source = veteran['changeOfAddress']
        change_of_address.city = change_of_address_source['city']
        change_of_address.state = change_of_address_source['state']
        change_of_address.country = change_of_address_source['country']
        change_of_address.number_and_street = change_of_address_source['addressLine1']
        change_of_address.apartment_or_unit_number = change_of_address_source['addressLine2']
        if change_of_address_source['addressLine3']
          # TODO: make sure the below concat doesn't exceed field length (pending discussions with stakeholders)
          change_of_address.apartment_or_unit_number += change_of_address_source['addressLine3']
        end

        change_of_address.zip_first_five = change_of_address_source['zipFirstFive']
        change_of_address.zip_last_four = change_of_address_source['zipLastFour']
        change_of_address.type_of_address_change = change_of_address_source['addressChangeType']
        change_of_address.dates = Requests::Dates.new
        change_of_address.dates.begin_date = change_of_address_source['beginningDate']
        change_of_address.dates.end_date = change_of_address_source['endingDate']

        change_of_address
      end

      def transform_homeless(veteran)
        homeless = Requests::Homeless.new
        homelessness = veteran['homelessness']
        homeless.currently_homeless = Requests::CurrentlyHomeless.new(
          homeless_situation_options: homelessness['currentlyHomeless'],
          other_description: homelessness['otherLivingSituation']
        )
        homeless.risk_of_becoming_homeless = Requests::RiskOfBecomingHomeless.new(
          living_situation_options: homelessness['homelessnessRiskSituationType '],
          other_description: homelessness['otherLivingSituation']
        )
        homeless.point_of_contact = homelessness['pointOfContact']['pointOfContactName']
        primary_phone = homelessness['pointOfContact']['primaryPhone']
        homeless.point_of_contact_number = Requests::ContactNumber.new(
          telephone: primary_phone['areaCode'] + primary_phone['phoneNumber']
        )
        homeless
      end

      private

      def transform_mailing_address(veteran, veteran_identification)
        veteran_identification.mailing_address = Requests::MailingAddress.new
        veteran_identification.mailing_address.number_and_street = veteran['currentMailingAddress']['addressLine1']
        veteran_identification.mailing_address.apartment_or_unit_number =
          veteran['currentMailingAddress']['addressLine2']
        if veteran['currentMailingAddress']['addressLine3']
          # TODO: make sure the below concat doesn't exceed field length (pending discussions with stakeholders)
          veteran_identification.mailing_address.apartment_or_unit_number +=
            veteran['currentMailingAddress']['addressLine3']
        end
        veteran_identification.mailing_address.city = veteran['currentMailingAddress']['city']
        veteran_identification.mailing_address.state = veteran['currentMailingAddress']['state']
        veteran_identification.mailing_address.zip_first_five = veteran['currentMailingAddress']['zipFirstFive']
        veteran_identification.mailing_address.zip_last_four = veteran['currentMailingAddress']['zipLastFour']
        veteran_identification.mailing_address.country = veteran['currentMailingAddress']['country']
      end
    end
  end
end
