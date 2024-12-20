# frozen_string_literal: true

module RepresentationManagement
  class NextStepsPdfData
    include ActiveModel::Model

    next_steps_pdf_attrs = %i[
      organization_id
      representative_id
    ]

    attr_accessor(*next_steps_pdf_attrs)

    validate :org_or_rep_specified?
    validate :entities_exist?

    def organization
      @organization ||= find_organization
    end

    def representative
      @representative ||= find_representative
    end

    # def entity_display_type
    #   if entity.is_a?(Veteran::Service::Representative) || entity.is_a?(AccreditedIndividual)
    #     representative_type
    #   else
    #     'Veterans Service Organization'
    #   end
    # end

    # def entity_name
    #   if entity_type == 'individual'
    #     entity.full_name.strip
    #   elsif entity_type == 'organization'
    #     entity.name.strip
    #   end
    # end

    # def entity_address
    #   <<~ADDRESS.squish
    #     #{entity.address_line1}
    #     #{entity.address_line2}
    #     #{entity.address_line3}
    #     #{entity.city}, #{entity.state_code} #{entity.zip_code}
    #     #{entity.country_code_iso3}
    #   ADDRESS
    # end

    private

    # def find_entity
    #   if entity_type == 'individual'
    #     find_representative
    #   elsif entity_type == 'organization'
    #     find_organization
    #   end
    # end

    def entities_exist?
      return unless organization.nil? && representative.nil?

      errors.add(:base, 'Organization or representative not found')
    end

    def org_or_rep_specified?
      return unless organization_id.present? || representative_id.present?

      errors.add(:base, 'At least one of organization_id or representative_id must be specified')
    end

    def find_organization
      AccreditedOrganization.find_by(id: organization_id) ||
        Veteran::Service::Organization.find_by(poa: organization_id)
    end

    def find_representative
      AccreditedIndividual.find_by(id: representative_id) ||
        Veteran::Service::Representative.find_by(representative_id: representative_id)
    end

    # def representative_type
    #   if entity.is_a?(Veteran::Service::Representative)
    #     type_string = entity.user_types.first
    #   elsif entity.is_a?(AccreditedIndividual)
    #     type_string = entity.individual_type
    #   end
    #   return '' if type_string.blank?

    #   case type_string
    #   when 'claims_agent', 'claim_agents'
    #     'claims agent'
    #   when 'representative', 'veteran_service_officer'
    #     'VSO representative'
    #   when 'attorney'
    #     'attorney'
    #   else
    #     ''
    #   end
    # end
  end
end
