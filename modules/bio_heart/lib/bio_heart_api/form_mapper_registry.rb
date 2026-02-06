# frozen_string_literal: true

require 'bio_heart_api/form_mappers/form_21p0537_mapper'
require 'ibm/service'

module BioHeartApi
  class FormMapperRegistry
    MAPPERS = {
      '21P-0537' => BioHeartApi::FormMappers::Form21p0537Mapper
    }.freeze

    def self.mapper_for(form_number)
      mapper_class = MAPPERS[form_number]
      raise ArgumentError, "No mapper found for form #{form_number}" unless mapper_class

      mapper_class
    end
  end
end
