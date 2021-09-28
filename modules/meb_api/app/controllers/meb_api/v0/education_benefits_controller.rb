# frozen_string_literal: true

module MebApi
  module V0
    class EducationBenefitsController < MebApi::V0::BaseController
      def claimant_info
        render json:
          { data: {
            "claimant": {
              "claimantId": 0, "firstName": 'Hector', "middleName": 'Oliver', "lastName": 'Stanley',
              "dateOfBirth": '1992-07-23',
              "contactInfos": [{ "addressLine1": '2222 Avon Street', "addressLine2": 'Apt 6',
                                 "addressLine3": 'string', "city": 'Arlington', "zipcode": '22205',
                                 "effectiveDate": '2021-09-17', "emailAddress": 'vets.gov.user+1@gmail.com',
                                 "addressType": 'DOMESTIC' }],
              "personComments": [{ "personCommentKey": 0, "commentDate": '2021-09-23', "comments": 'string' }],
              "dobChanged": true,
              "firstAndLastNameChanged": true
            }
          } }
      end

      def service_history
        render json:
        { data: {
          "beginDate": '2021-09-23',
          "endDate": '2021-09-23',
          "branchOfService": 'ArmyActiveDuty',
          "trainingPeriods": [
            {
              "beginDate": '2021-09-23',
              "endDate": '2021-09-23'
            }
          ],
          "exclusionPeriods": [{ "beginDate": '2021-09-23', "endDate": '2021-09-23' }],
          "characterOfService": 'string',
          "separationReason": 'string',
          "serviceStatus": 'Veteran',
          "disagreeWithServicePeriod": true
        } }
      end

      def eligibility
        render json:
        { data: {
          "veteranIsEligible": true,
          "chapter": 'chapter33'
        } }
      end

      def claim_status
        render json:
        { data: {
          "claimId": 0,
          "status": 'InProgress'
        } }
      end
    end
  end
end
