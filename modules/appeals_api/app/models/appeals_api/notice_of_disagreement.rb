# frozen_string_literal: true

require 'json_marshal/marshaller'
require 'common/exceptions'

module AppealsApi
  class NoticeOfDisagreement < ApplicationRecord
    include CentralMailStatus

    def self.load_json_schema(filename)
      MultiJson.load File.read Rails.root.join('modules', 'appeals_api', 'config', 'schemas', "#{filename}.json")
    end

    def self.date_from_string(string)
      string.match(/\d{4}-\d{2}-\d{2}/) && Date.parse(string)
    rescue ArgumentError
      nil
    end

    attr_encrypted(:form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)
    attr_encrypted(:auth_headers, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller)

    validate(
      :validate_hearing_type_selection,
      :validate_address_unless_homeless,
      if: proc { |a| a.form_data.present? }
    )

    def pdf_structure(version)
      Object.const_get(
        "AppealsApi::PdfConstruction::NoticeOfDisagreement::#{version.upcase}::Structure"
      ).new(self)
    end

    def veteran_first_name
      header_field_as_string 'X-VA-Veteran-First-Name'
    end

    def veteran_last_name
      header_field_as_string 'X-VA-Veteran-Last-Name'
    end

    def ssn
      header_field_as_string 'X-VA-Veteran-SSN'
    end

    def file_number
      header_field_as_string 'X-VA-Veteran-File-Number'
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
        veteran_contact_info.dig('address', 'zipCode5'),
        veteran_contact_info.dig('address', 'countryName')
      ].compact.map(&:strip).join(', ')
    end

    def phone
      AppealsApi::HigherLevelReview::Phone.new(veteran_contact_info&.dig('phone')).to_s
    end

    def email
      veteran_contact_info.dig('emailAddressText')
    end

    def veteran_homeless?
      form_data&.dig('data', 'attributes', 'veteran', 'homeless')
    end

    def veteran_representative
      form_data&.dig('data', 'attributes', 'veteran', 'representativesName')
    end

    def board_review_option
      form_data&.dig('data', 'attributes', 'boardReviewOption')
    end

    def hearing_type_preference
      form_data&.dig('data', 'attributes', 'hearingTypePreference')
    end

    def zip_code_5
      form_data&.dig('data', 'attributes', 'veteran', 'address', 'zipCode5')
    end

    def lob
      'BVA'
    end

    private

    def validate_address_unless_homeless
      return if veteran_homeless?

      errors.add :form_data, I18n.t('appeals_api.errors.not_homeless_address_missing') if mailing_address.blank?
    end

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
      board_review_option == 'hearing'
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
  end
end
