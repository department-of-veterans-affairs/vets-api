# frozen_string_literal: true

module IvcChampva
  class VHA107959f1
    STATS_KEY = 'api.ivc_champva_form.10_7959f_1'

    include Virtus.model(nullify_blank: true)
    include Attachments

    attribute :data
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959f_1'
    end

    def words_to_remove
      veteran_ssn + veteran_date_of_birth + veteran_mailing_address + veteran_email +
        veteran_physical_address + veteran_home_phone
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranMiddleName' => @data.dig('veteran', 'full_name', 'middle'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'mailing_address', 'postal_code') || '00000',
        'country' => @data.dig('veteran', 'mailing_address', 'country') || 'USA',
        'source' => 'VA Platform Digital Forms',
        'ssn_or_tin' => @data.dig('veteran', 'ssn'),
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info']
      }
    end

    def desired_stamps
      [{ coords: [26, 82.5], text: data['statement_of_truth_signature'], page: 0 }]
    end

    def track_current_user_loa(current_user)
      current_user_loa = current_user&.loa&.[](:current) || 0
      StatsD.increment("#{STATS_KEY}.#{current_user_loa}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959F-1 Current User LOA', current_user_loa:)
    end

    def track_email_usage
      email_used = metadata&.dig('primaryContactInfo', 'email') ? 'yes' : 'no'
      StatsD.increment("#{STATS_KEY}.#{email_used}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959F-1 Email Used', email_used:)
    end

    def method_missing(_, *args)
      args&.first
    end

    def respond_to_missing?(_)
      true
    end

    private

    def veteran_ssn
      [
        data.dig('veteran', 'ssn')
      ]
    end

    def veteran_date_of_birth
      [
        data.dig('veteran', 'date_of_birth')
      ]
    end

    def veteran_mailing_address
      [
        data.dig('veteran', 'mailing_address_string')
      ]
    end

    def veteran_email
      [
        data.dig('veteran', 'email_address')
      ]
    end

    def veteran_physical_address
      [
        data.dig('veteran', 'physical_address_string')
      ]
    end

    def veteran_home_phone
      [
        data.dig('veteran', 'phone_number')
      ]
    end
  end
end
