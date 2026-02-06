# frozen_string_literal: true

require 'vets/model'

module IvcChampva
  class VHA107959f22025
    STATS_KEY = 'api.ivc_champva_form.10_7959f_2_2025'

    include Vets::Model
    include Attachments

    attribute :data, Hash
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959f_2_2025'
    end

    def metadata
      name_prefix = Flipper.enabled?(:champva_update_metadata_keys) ? 'sponsor' : 'veteran'

      {
        "#{name_prefix}FirstName" => @data.dig('veteran', 'full_name', 'first'),
        "#{name_prefix}MiddleName" => @data.dig('veteran', 'full_name', 'middle'),
        "#{name_prefix}LastName" => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'mailing_address', 'postal_code') || '00000',
        'country' => @data.dig('veteran', 'mailing_address', 'country') || 'USA',
        'source' => 'VA Platform Digital Forms',
        'ssn_or_tin' => @data.dig('veteran', 'ssn'),
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info'],
        'primaryContactEmail' => @data.dig('primary_contact_info', 'email').to_s,
        'formExpiration' => '12/31/2027'
      }
    end

    def track_current_user_loa(current_user)
      current_user_loa = current_user&.loa&.[](:current) || 0
      StatsD.increment("#{STATS_KEY}.#{current_user_loa}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959F-2-2025 Current User LOA', current_user_loa:)
    end

    def track_email_usage
      email_used = metadata&.dig('primaryContactInfo', 'email') ? 'yes' : 'no'
      StatsD.increment("#{STATS_KEY}.#{email_used}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959F-2-2025 Email Used', email_used:)
    end

    def method_missing(_, *args)
      args&.first
    end

    def respond_to_missing?(_method_name, _include_private = false)
      true
    end
  end
end
