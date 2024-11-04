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

    def entity
      @entity ||= find_entity
    end

    def representative_type_humanized
      @representative_type_humanized ||= representative_type.humanize.titleize
    end

    private

    def find_entity
      if entity_type == 'individual'
        find_representative
      elsif entity_type == 'organization'
        find_organization
      end
    end

    def find_representative
      AccreditedIndividual.find_by(id: entity_id) ||
        Veteran::Service::Representative.find_by(representative_id: entity_id)
    end

    def find_organization
      AccreditedOrganization.find_by(id: entity_id) ||
        Veteran::Service::Organization.find_by(poa: entity_id)
    end
  end
end
