# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class CheckInDemographics
        # rubocop:disable Metrics/MethodLength
        def parse(demographics)
          json = JSON.parse(demographics.body, symbolize_names: true)[:data]

          {
            insuranceVerificationNeeded: json[:insuranceVerificationNeeded],
            needsConfirmation: json[:needsConfirmation],
            mailingAddress: { street1: json.dig(:mailingAddress, :street1),
                              street2: json.dig(:mailingAddress, :street2),
                              street3: json.dig(:mailingAddress, :street3),
                              city: json.dig(:mailingAddress, :city),
                              county: json.dig(:mailingAddress, :county),
                              state: json.dig(:mailingAddress, :state),
                              zip: json.dig(:mailingAddress, :zip),
                              zip4: json.dig(:mailingAddress, :zip4),
                              country: json.dig(:mailingAddress, :country) },
            residentialAddress: { street1: json.dig(:residentialAddress, :street1),
                                  street2: json.dig(:residentialAddress, :street2),
                                  street3: json.dig(:residentialAddress, :street3),
                                  city: json.dig(:residentialAddress, :city),
                                  county: json.dig(:residentialAddress, :county),
                                  state: json.dig(:residentialAddress, :state),
                                  zip: json.dig(:residentialAddress, :zip),
                                  zip4: json.dig(:residentialAddress, :zip4),
                                  country: json.dig(:residentialAddress, :country) },
            homePhone: json[:homePhone],
            officePhone: json[:officePhone],
            cellPhone: json[:cellPhone],
            email: json[:email],
            emergencyContact: { name: json.dig(:emergencyContact, :name),
                                relationship: json.dig(:emergencyContact, :relationship),
                                phone: json.dig(:emergencyContact, :phone),
                                workPhone: json.dig(:emergencyContact, :workPhone),
                                address: { street1: json.dig(:emergencyContact, :address, :street1),
                                           street2: json.dig(:emergencyContact, :address, :street2),
                                           street3: json.dig(:emergencyContact, :address, :street3),
                                           city: json.dig(:emergencyContact, :address, :city),
                                           county: json.dig(:emergencyContact, :address, :county),
                                           state: json.dig(:emergencyContact, :address, :state),
                                           zip: json.dig(:emergencyContact, :address, :zip),
                                           zip4: json.dig(:emergencyContact, :address, :zip4),
                                           country: json.dig(:emergencyContact, :address, :country) },
                                needsConfirmation: json.dig(:emergencyContact, :needsConfirmation) },
            nextOfKin: { name: json.dig(:nextOfKin, :name),
                         relationship: json.dig(:nextOfKin, :relationship),
                         phone: json.dig(:nextOfKin, :phone),
                         workPhone: json.dig(:nextOfKin, :workPhone),
                         address: { street1: json.dig(:nextOfKin, :address, :street1),
                                    street2: json.dig(:nextOfKin, :address, :street2),
                                    street3: json.dig(:nextOfKin, :address, :street3),
                                    city: json.dig(:nextOfKin, :address, :city),
                                    county: json.dig(:nextOfKin, :address, :county),
                                    state: json.dig(:nextOfKin, :address, :state),
                                    zip: json.dig(:nextOfKin, :address, :zip),
                                    zip4: json.dig(:nextOfKin, :address, :zip4),
                                    country: json.dig(:nextOfKin, :address,
                                                      :country) },
                         needsConfirmation: json.dig(:nextOfKin, :needsConfirmation) }
          }
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
