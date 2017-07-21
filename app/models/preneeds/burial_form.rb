# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class BurialForm < Preneeds::Base
    attribute :application_status, String
    attribute :has_attachments, Boolean
    attribute :has_currently_buried, String
    attribute :sending_application, String, default: 'vets.gov'
    attribute :sending_code, String
    attribute :sent_time, Common::UTCTime, default: :current_time
    attribute :tracking_number, String, default: :generate_tracking_number

    attribute :applicant, Preneeds::Applicant
    attribute :claimant, Preneeds::Claimant
    attribute :currently_buried_persons, Array[Preneeds::CurrentlyBuriedPerson]
    attribute :veteran, Preneeds::Veteran

    def current_time
      Time.now.utc
    end

    def generate_tracking_number
      "#{SecureRandom.base64(14).tr('+/=', '0aZ')[0..-3]}VG"
    end

    # Hash attributes must correspond to xsd ordering or API call will fail
    def message
      hash = {
        applicant: applicant.message, applicationStatus: application_status || '',
        claimant: claimant.message, currentlyBuriedPersons: currently_buried_persons.map(&:message),
        hasAttachments: has_attachments, hasCurrentlyBuried: has_currently_buried,
        sendingApplication: sending_application, sendingCode: sending_code || '', sentTime: sent_time.iso8601,
        trackingNumber: tracking_number, veteran: veteran.message
      }

      [:currently_buried_persons].each do |key|
        hash.delete(key) if hash[key].nil?
      end

      hash
    end

    def validate(schema, root)
      json = { root => message }

      JSON::Validator.fully_validate(schema, json, validate_schema: true)
    end
  end
end
