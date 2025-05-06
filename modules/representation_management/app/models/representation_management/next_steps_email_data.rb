# frozen_string_literal: true

module RepresentationManagement
  class NextStepsEmailData
    include ActiveModel::Model

    next_steps_email_attrs = %i[
      email_address
      first_name
      form_name
      form_number
      entity_type
      entity_id
    ]

    attr_accessor(*next_steps_email_attrs)

    validates :email_address, presence: true
    validates :first_name, presence: true
    validates :form_name, presence: true
    validates :form_number, presence: true
    validates :entity_type, presence: true
    validates :entity_id, presence: true
    validate :entity_exists?

    def entity
      @entity ||= find_entity
    end

    def entity_display_type
      if entity.is_a?(Veteran::Service::Representative) || entity.is_a?(AccreditedIndividual)
        representative_type
      else
        'Veterans Service Organization'
      end
    end

    def entity_name
      if entity_type == 'individual'
        entity.full_name.strip
      elsif entity_type == 'organization'
        entity.name.strip
      end
    end

    def entity_address
      <<~ADDRESS.squish
        #{entity.address_line1}
        #{entity.address_line2}
        #{entity.address_line3}
        #{entity.city}, #{entity.state_code} #{entity.zip_code}
        #{entity.country_code_iso3}
      ADDRESS
    end

    private

    def find_entity
      if entity_type == 'individual'
        find_representative
      elsif entity_type == 'organization'
        find_organization
      end
    end

    def entity_exists?
      return unless entity.nil?

      errors.add(:entity, 'Entity not found')
    end

    def find_representative
      AccreditedIndividual.find_by(id: entity_id) ||
        Veteran::Service::Representative.find_by(representative_id: entity_id)
    end

    def find_organization
      AccreditedOrganization.find_by(id: entity_id) ||
        Veteran::Service::Organization.find_by(poa: entity_id)
    end

    def representative_type
      if entity.is_a?(Veteran::Service::Representative)
        type_string = entity.user_types.first
      elsif entity.is_a?(AccreditedIndividual)
        type_string = entity.individual_type
      end
      return '' if type_string.blank?

      case type_string
      when 'claims_agent', 'claim_agents'
        'claims agent'
      when 'representative', 'veteran_service_officer'
        'VSO representative'
      when 'attorney'
        'attorney'
      else
        ''
      end
    end
  end
end
