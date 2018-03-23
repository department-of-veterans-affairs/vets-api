# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Alert
        include Swagger::Blocks

        swagger_schema :Alert do
          property :type, type: :string, enum: %w[
            form9_needed scheduled_hearing hearing_no_show held_for_evidence cavc_option
            ramp_eligible ramp_ineligible decision_soon blocked_by_vso
            scheduled_dro_hearing dro_hearing_no_show
          ], example: 'TODO'
          property :details, type: :object, example: 'TODO'
        end
      end
    end
  end
end
