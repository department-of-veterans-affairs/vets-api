# frozen_string_literal: true

module FormTransformers
  module BenefitsDiscovery
    class HealthCareApplicationTransformer < BaseTransformer
      def transform
        {
          dateOfBirth: date_of_birth,
          disabilityRating: 60,
          serviceDates: [service_history]
        }
      end

      private

      def date_of_birth
        @form['veteranDateOfBirth']
      end

      def service_history
        {
          startDate: @form['lastEntryDate'],
          endDate: @form['lastDischargeDate'],
          dischargeStatus: @form['dischargeType'].upcase,
          branchOfService: @form['lastServiceBranch'].upcase
        }
      end

      def purple_heart_recipient
        @form['purpleHeartRecipient']
      end
    end
  end
end
