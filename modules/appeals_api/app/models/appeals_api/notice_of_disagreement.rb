# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/exceptions'

module AppealsApi
  class NoticeOfDisagreement < ApplicationRecord
    include NodStatus

    scope :pii_expunge_policy, lambda {
      where(
        status: COMPLETE_STATUSES
      ).and(
        where('updated_at < ? AND board_review_option IN (?)', 1.week.ago, %w[hearing direct_review])
        .or(where('updated_at < ? AND board_review_option IN (?)', 91.days.ago, 'evidence_submission'))
      )
    }

    def self.load_json_schema(filename)
      MultiJson.load File.read Rails.root.join('modules', 'appeals_api', 'config', 'schemas', "#{filename}.json")
    end

    def self.date_from_string(string)
      string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
    rescue ArgumentError
      nil
    end

    serialize :auth_headers, JsonMarshal::Marshaller
    serialize :form_data, JsonMarshal::Marshaller
    has_kms_key
    encrypts :auth_headers, :form_data, key: :kms_key

    validate :validate_hearing_type_selection, if: :pii_present?

    has_many :evidence_submissions, as: :supportable, dependent: :destroy
    has_many :status_updates, as: :statusable, dependent: :destroy

    def pdf_structure(version)
      Object.const_get(
        "AppealsApi::PdfConstruction::NoticeOfDisagreement::#{version.upcase}::Structure"
      ).new(self)
    end

    def veteran_first_name
      header_field_as_string 'X-VA-First-Name'
    end

    def veteran_last_name
      header_field_as_string 'X-VA-Last-Name'
    end

    def ssn
      header_field_as_string 'X-VA-SSN'
    end

    def file_number
      header_field_as_string 'X-VA-File-Number'
    end

    def consumer_name
      header_field_as_string 'X-Consumer-Username'
    end

    def consumer_id
      header_field_as_string 'X-Consumer-ID'
    end

    def veteran_contact_info
      form_data&.dig('data', 'attributes', 'veteran')
    end

    def mailing_address
      address_combined = [
        veteran_contact_info.dig('address', 'addressLine1'),
        veteran_contact_info.dig('address', 'addressLine2'),
        veteran_contact_info.dig('address', 'addressLine3')
      ].compact.map(&:strip).join(' ')

      [
        address_combined,
        veteran_contact_info.dig('address', 'city'),
        veteran_contact_info.dig('address', 'stateCode'),
        zip_code_5_or_international_postal_code,
        veteran_contact_info.dig('address', 'countryName')
      ].compact.map(&:strip).join(', ')
    end

    def phone
      AppealsApi::HigherLevelReview::Phone.new(veteran_contact_info&.dig('phone')).to_s
    end

    def email
      veteran_contact_info['emailAddressText']
    end

    def veteran_homeless?
      form_data&.dig('data', 'attributes', 'veteran', 'homeless')
    end

    def veteran_representative
      form_data&.dig('data', 'attributes', 'veteran', 'representativesName')
    end

    def board_review_value
      form_data&.dig('data', 'attributes', 'boardReviewOption')
    end

    def hearing_type_preference
      form_data&.dig('data', 'attributes', 'hearingTypePreference')
    end

    def zip_code_5
      # schema already validated address presence if not homeless
      veteran_contact_info&.dig('address', 'zipCode5') || '00000'
    end

    def zip_code_5_or_international_postal_code
      zip = zip_code_5
      return zip unless zip == '00000'

      veteran_contact_info&.dig('address', 'internationalPostalCode')
    end

    def lob
      'BVA'
    end

    def accepts_evidence?
      board_review_option == 'evidence_submission'
    end

    def evidence_submission_days_window
      91
    end

    def outside_submission_window_error
      {
        title: 'unprocessable_entity',
        detail: I18n.t('appeals_api.errors.nod_outside_legal_window'),
        code: 'OutsideLegalWindow',
        status: '422'
      }
    end

    def update_status!(status:, code: nil, detail: nil)
      handler = Events::Handler.new(event_type: :nod_status_updated, opts: {
                                      from: self.status,
                                      to: status,
                                      status_update_time: Time.zone.now.iso8601,
                                      statusable_id: id
                                    })

      update!(status: status, code: code, detail: detail)

      handler.handle!
    end

    private

    def validate_hearing_type_selection
      return if board_review_hearing_selected? && includes_hearing_type_preference?

      source = '/data/attributes/hearingTypePreference'
      data = I18n.t('common.exceptions.validation_errors')

      if hearing_type_missing?
        errors.add source, data.merge(detail: I18n.t('appeals_api.errors.hearing_type_preference_missing'))
      elsif unexpected_hearing_type_inclusion?
        errors.add source, data.merge(detail: I18n.t('appeals_api.errors.hearing_type_preference_inclusion'))
      end
    end

    def board_review_hearing_selected?
      board_review_value == 'hearing'
    end

    def includes_hearing_type_preference?
      hearing_type_preference.present?
    end

    def hearing_type_missing?
      board_review_hearing_selected? && !includes_hearing_type_preference?
    end

    def unexpected_hearing_type_inclusion?
      !board_review_hearing_selected? && includes_hearing_type_preference?
    end

    def birth_date(who)
      self.class.date_from_string header_field_as_string "X-VA-#{who}-Birth-Date"
    end

    def header_field_as_string(key)
      auth_headers&.dig(key).to_s.strip
    end

    # After expunging pii, form_data is nil, update will fail unless validation skipped
    def pii_present?
      proc { |a| a.form_data.present? }
    end
  end
end
