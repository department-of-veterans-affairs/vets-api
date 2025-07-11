# frozen_string_literal: true

require 'representation_management/engine'

module RepresentationManagement
  AGENTS = 'agents'
  ATTORNEYS = 'attorneys'
  REPRESENTATIVES = 'representatives'

  # rubocop:disable Layout/LineLength
  ENTITY_CONFIG = OpenStruct.new({
                                   AGENTS => OpenStruct.new({
                                                              api_type: 'agent',
                                                              individual_type: 'claims_agent',
                                                              responses_var: :@agent_responses,
                                                              ids_var: :@agent_ids,
                                                              json_var: :@agent_json_for_address_validation,
                                                              validation_description: 'Batching agent address updates from GCLAWS Accreditation API'
                                                            }),
                                   ATTORNEYS => OpenStruct.new({
                                                                 api_type: 'attorney',
                                                                 individual_type: 'attorney',
                                                                 responses_var: :@attorney_responses,
                                                                 ids_var: :@attorney_ids,
                                                                 json_var: :@attorney_json_for_address_validation,
                                                                 validation_description: 'Batching attorney address updates from GCLAWS Accreditation API'
                                                               }),
                                   REPRESENTATIVES => OpenStruct.new({
                                                                       api_type: 'representative',
                                                                       individual_type: 'representative',
                                                                       responses_var: :@representative_responses,
                                                                       ids_var: :@representative_ids,
                                                                       json_var: :@representative_json_for_address_validation,
                                                                       validation_description: 'Batching representative address updates from GCLAWS Accreditation API'
                                                                     })
                                 }).freeze
  # rubocop:enable Layout/LineLength
end
