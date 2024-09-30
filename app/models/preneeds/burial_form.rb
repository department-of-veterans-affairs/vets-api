# frozen_string_literal: true

# Preneeds namespace
#
module Preneeds
  # Models a Preneeds Burial form. This class (and associationed classes) is used to store form details and to
  # generate the XML request for submission to the EOAS service
  #
  # @!attribute application_status
  #   @return [String] currently always blank
  # @!attribute preneed_attachments
  #   @return [Array<PreneedAttachmentHash>] documents provided by the end user
  # @!attribute has_currently_buried
  #   @return [String] '1' for Yes, '2' for No, '3' for Don't know
  # @!attribute sending_application
  #   @return [String] hard coded as 'va.gov'
  # @!attribute sending_code
  #   @return [String] currently always blank
  # @!attribute sent_time
  #   @return [Time] current time
  # @!attribute tracking_number
  #   @return [String] SecureRandom generated tracking number sent with submission to EOAS
  # @!attribute applicant
  #   @return [Preneeds::Applicant] Applicant object. Applicant is person filling out the form.
  # @!attribute claimant
  #   @return [Preneeds::Claimant] Claimant object. Claimant is the person applying for the
  #     benefit (veteran or relative)
  # @!attribute currently_buried_persons
  #   @return [Array<Preneeds::CurrentlyBuriedPerson>] CurrentlyBuriedPerson objects representing individuals burried in
  #     VA national cemeteries under the sponsor's eligibility
  # @!attribute veteran
  #   @return [Preneeds::Veteran] Veteran object.  Veteran is the person who is the owner of the benefit.
  #
  class BurialForm < Preneeds::Base
    # Preneeds Burial Form official form id
    #
    FORM = '40-10007'

    attribute :application_status, String, default: ''
    attribute :preneed_attachments, PreneedAttachmentHash, array: true
    attribute :has_currently_buried, String
    attribute :sending_application, String, default: 'vets.gov'
    attribute :sending_code, String, default: ''
    attribute :sent_time, Common::UTCTime, default: :current_time
    attribute :tracking_number, String, default: :generate_tracking_number
    attribute :applicant, Preneeds::Applicant
    attribute :claimant, Preneeds::Claimant
    attribute :currently_buried_persons, Preneeds::CurrentlyBuriedPerson, array: true
    attribute :veteran, Preneeds::Veteran

    # keeping this name because it matches the previous attribute
    # @return [Boolean]
    #
    # rubocop:disable Naming/PredicateName
    def has_attachments
      preneed_attachments.present?
    end
    # rubocop:enable Naming/PredicateName

    # @return [Array<Preneeds::Attachment>] #preneed_attachments converted to Array of {Preneeds::Attachment}
    #
    def attachments
      @attachments ||= preneed_attachments.map(&:to_attachment)
    end

    # @return [Time] current UTC time
    #
    def current_time
      Time.now.utc
    end

    # @return [String] randomly generated tracking number
    #
    def generate_tracking_number
      "#{SecureRandom.base64(14).tr('+/=', '0aZ')[0..-3]}VG"
    end

    # Converts object attributes to a hash to be used when constructing a SOAP request body.
    # Hash attributes must correspond to XSD ordering or API call will fail
    #
    # @return [Hash] object attributes and association objects converted to EOAS service compatible hash
    #
    def as_eoas
      hash = {
        applicant: applicant&.as_eoas, applicationStatus: application_status,
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

    # @return [Array<String>] array of strings detailing schema validation failures. empty array if form is valid
    #
    def self.validate(schema, form, root = 'application')
      JSON::Validator.fully_validate(schema, { root => form&.as_json }, validate_schema: true)
    end
  end
end
