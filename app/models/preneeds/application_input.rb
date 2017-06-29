# frozen_string_literal: true
require 'common/models/base'

# DischargeType model
module Preneeds
  class ApplicationInput < Common::Base
    include ActiveModel::Validations

    validate :validate_applicant, if: -> (v) { v.applicant.present? }
    validate :validate_claimant, if: -> (v) { v.claimant.present? }
    validate :validate_currently_buried_persons, if: -> (v) { v.currently_buried_persons.present? }
    validate :validate_veteran, if: -> (v) { v.veteran.present? }

    validates :applicant, :claimant, :veteran, :sent_time, presence: true
    validates :has_currently_buried, inclusion: { in: %w(1 2 3) }
    validates :tracking_number, length: { is: 20 }, presence: true
    validates :has_attachments, inclusion: { in: [true, false] }

    attribute :applicant, ApplicantInput
    attribute :application_status, String
    attribute :claimant, ClaimantInput
    attribute :currently_buried_persons, Array[CurrentlyBuriedInput]
    attribute :has_attachments, Boolean
    attribute :has_currently_buried, String
    attribute :sending_application, String, default: 'vets.gov'
    attribute :sending_code, String
    attribute :sent_time, Common::UTCTime, default: :current_time
    attribute :tracking_number, String, default: :generate_tracking_number
    attribute :veteran, VeteranInput

    def current_time
      Time.now.utc
    end

    def generate_tracking_number
      "#{SecureRandom.base64(14).tr('+/=', '0aZ')[0..-3]}VG"
    end

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

    private

    def validate_applicant
      errors.add(:applicant, applicant.errors.full_messages.join(', ')) unless applicant.valid?
    end

    def validate_claimant
      errors.add(:claimant, claimant.errors.full_messages.join(', ')) unless claimant.valid?
    end

    def validate_currently_buried_persons
      buried_persons_errors = currently_buried_persons.each_with_object([]) do |buried, o|
        o << buried.errors.full_messages.join(', ') unless buried.valid?
      end

      errors.add(:currently_buried_persons, buried_persons_errors.join(', ')) if buried_persons_errors.present?
    end

    def validate_veteran
      errors.add(:veteran, veteran.errors.full_messages.join(', ')) unless veteran.valid?
    end
  end
end
