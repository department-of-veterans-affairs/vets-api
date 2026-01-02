# frozen_string_literal: true

require 'representation_management/engine'

module RepresentationManagement
  AGENTS = 'agents'
  ATTORNEYS = 'attorneys'
  REPRESENTATIVES = 'representatives'
  VSOS = 'veteran_service_organizations'

  # rubocop:disable Layout/LineLength
  ENTITY_CONFIG = OpenStruct.new({
                                   AGENTS => OpenStruct.new({
                                                              api_type: 'agent',
                                                              individual_type: 'claims_agent',
                                                              ids_var: :@agent_ids,
                                                              validation_ids_var: :@agent_ids_for_address_validation,
                                                              validation_description: 'Batching agent address updates from GCLAWS Accreditation API'
                                                            }),
                                   ATTORNEYS => OpenStruct.new({
                                                                 api_type: 'attorney',
                                                                 individual_type: 'attorney',
                                                                 ids_var: :@attorney_ids,
                                                                 validation_ids_var: :@attorney_ids_for_address_validation,
                                                                 validation_description: 'Batching attorney address updates from GCLAWS Accreditation API'
                                                               }),
                                   REPRESENTATIVES => OpenStruct.new({
                                                                       api_type: 'representative',
                                                                       individual_type: 'representative',
                                                                       ids_var: :@representative_ids,
                                                                       validation_ids_var: :@representative_ids_for_address_validation,
                                                                       validation_description: 'Batching representative address updates from GCLAWS Accreditation API'
                                                                     }),
                                   VSOS => OpenStruct.new({
                                                            api_type: 'veteran_service_organization',
                                                            individual_type: 'veteran_service_organization',
                                                            ids_var: :@vso_ids,
                                                            validation_ids_var: :@vso_ids_for_address_validation,
                                                            validation_description: 'Batching VSO address updates from GCLAWS Accreditation API'
                                                          })
                                 }).freeze
end
# rubocop:enable Layout/LineLength
