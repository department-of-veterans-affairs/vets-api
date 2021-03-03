# frozen_string_literal: true

require 'claims_api/field_mapper_base'

module ClaimsApi
  module SpecialIssueMappers
    class Evss < ClaimsApi::FieldMapperBase
      protected

      def items
        [
          { name: 'ALS', code: 'ALS' },
          { name: 'HEPC', code: 'HEPC' },
          { name: 'POW', code: 'POW' },
          { name: 'PTSD/1', code: 'PTSD_1' },
          { name: 'PTSD/2', code: 'PTSD_2' },
          { name: 'PTSD/3', code: 'PTSD_3' },
          { name: 'PTSD/4', code: 'PTSD_4' },
          { name: 'MST', code: 'MST' },
          { name: 'Amyotrophic Lateral Sclerosis (ALS)', code: 'ALS' },
          { name: 'Hepatitis C', code: 'HEPC' },
          { name: 'PTSD - Combat', code: 'PTSD_1' },
          { name: 'PTSD - Non-Combat', code: 'PTSD_2' },
          { name: 'PTSD - Personal Trauma', code: 'PTSD_3' },
          { name: 'Non-PTSD Personal Trauma', code: 'PTSD_4' },
          { name: 'Military Sexual Trauma (MST)', code: 'MST' }
        ].freeze
      end
    end
  end
end
