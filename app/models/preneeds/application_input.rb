# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class ApplicationInput < Common::Base
    include ActiveModel::Validations

    # 1; Yes, 2: No, 3: Don't know
    HAS_BURIED_PERSONS = %w(1 2 3).freeze

    attribute :application_status, String
    attribute :has_attachments, Boolean
    attribute :has_currently_buried, String
    attribute :sending_application, String, default: 'vets.gov'
    attribute :sending_code, String
    attribute :sent_time, Common::UTCTime, default: :current_time
    attribute :tracking_number, String, default: :generate_tracking_number

    attribute :applicant, Preneeds::ApplicantInput
    attribute :claimant, Preneeds::ClaimantInput
    attribute :currently_buried_persons, Array[Preneeds::CurrentlyBuriedInput]
    attribute :veteran, Preneeds::VeteranInput

    # TODO: currently_buried_persons is an Array of max length 1, should be increased
    validates :sent_time, presence: true
    validates :has_currently_buried, inclusion: { in: HAS_BURIED_PERSONS }
    validates :tracking_number, length: { maximum: 20 }, presence: true
    validates :has_attachments, inclusion: { in: [true, false] }

    validates :applicant, :claimant, :veteran, presence: true, preneeds_embedded_object: true
    validates :currently_buried_persons, length: { maximum: 1 }, preneeds_embedded_object: true

    def current_time
      Time.now.utc
    end

    def generate_tracking_number
      "#{SecureRandom.base64(14).tr('+/=', '0aZ')[0..-3]}VG"
    end

    # Hash attributes must correspond to xsd ordering or API call will fail
    def message
      hash = {
        applicant: applicant.message, application_status: application_status || '',
        claimant: claimant.message, currently_buried_persons: currently_buried_persons.map(&:message),
        has_attachments: has_attachments, has_currently_buried: has_currently_buried,
        sending_application: sending_application, sending_code: sending_code || '', sent_time: sent_time.iso8601,
        tracking_number: tracking_number, veteran: veteran.message
      }

      [:currently_buried_persons].each do |key|
        hash.delete(key) if hash[key].nil?
      end

      hash
    end
  end
end
