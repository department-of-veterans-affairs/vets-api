# frozen_string_literal: true

module IvcChampva
  class VHA107959a
    STATS_KEY = 'api.ivc_champva_form.10_7959a'

    include Virtus.model(nullify_blank: true)
    include Attachments

    attribute :data
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959a'
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('applicant_name', 'first'),
        'veteranLastName' => @data.dig('applicant_name', 'last'),
        'zipCode' => @data.dig('applicant_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'ssn_or_tin' => @data['applicant_member_number'],
        'member_number' => @data['applicant_member_number'],
        'country' => @data.dig('applicant_address', 'country') || 'USA',
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info']
      }
    end

    def track_user_identity
      identity = data['certifier_role']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('IVC ChampVA Forms - 10-7959A Submission User Identity', identity:)
    end

    # rubocop:disable Naming/BlockForwarding,Style/HashSyntax
    def method_missing(method_name, *args, &block)
      super unless respond_to_missing?(method_name)
      { method: method_name, args: args }
    end
    # rubocop:enable Naming/BlockForwarding,Style/HashSyntax

    def respond_to_missing?(_method_name, _include_private = false)
      true
    end
  end
end
