# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  class BurialForm < Preneeds::Base
    attribute :application_status, String
    attribute :preneed_attachments, Array[PreneedAttachmentHash]
    attribute :has_currently_buried, String
    attribute :sending_application, String, default: 'vets.gov'
    attribute :sending_code, String
    attribute :sent_time, Common::UTCTime, default: :current_time
    attribute :tracking_number, String, default: :generate_tracking_number

    attribute :applicant, Preneeds::Applicant
    attribute :claimant, Preneeds::Claimant
    attribute :currently_buried_persons, Array[Preneeds::CurrentlyBuriedPerson]
    attribute :veteran, Preneeds::Veteran

    def self.create_forms_array(params_array)
      Array.wrap(params_array).map { |params| BurialForm.new(params) }
    end

    # keep this name because it matches the previous attribute
    # rubocop:disable Naming/PredicateName
    def has_attachments
      preneed_attachments.present?
    end
    # rubocop:enable Naming/PredicateName

    def attachments
      @attachments ||= preneed_attachments.map(&:to_attachment)
    end

    def current_time
      Time.now.utc
    end

    def generate_tracking_number
      "#{SecureRandom.base64(14).tr('+/=', '0aZ')[0..-3]}VG"
    end

    # Hash attributes must correspond to xsd ordering or API call will fail
    def as_eoas
      hash = {
        applicant: applicant&.as_eoas, applicationStatus: application_status || '',
        attachments: attachments.map(&:as_eoas),
        claimant: claimant&.as_eoas, currentlyBuriedPersons: currently_buried_persons.map(&:as_eoas),
        hasAttachments: has_attachments, hasCurrentlyBuried: has_currently_buried,
        sendingApplication: sending_application, sendingCode: sending_code || '', sentTime: sent_time.iso8601,
        trackingNumber: tracking_number, veteran: veteran&.as_eoas
      }

      [:currentlyBuriedPersons].each do |key|
        hash.delete(key) if hash[key].blank?
      end

      Common::HashHelpers.deep_compact(hash)
    end

    def self.validate(schema, form, root = 'application')
      JSON::Validator.fully_validate(schema, { root => form&.as_json }, validate_schema: true)
    end
  end
end
