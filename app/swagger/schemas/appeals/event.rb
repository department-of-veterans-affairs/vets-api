# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Event
        include Swagger::Blocks

        swagger_schema :Event do
          property :type, type: :string, enum: %w(claim_decision nod soc form9 ssoc certified hearing_held hearing_cancelled hearing_no_show bva_decision field_grant withdrawn ftr ramp death merged record_designation reconsideration vacated other_close cavc_decision ramp_notice transcript remand_return dro_hearing_held dro_hearing_cancelled dro_hearing_no_show), example: 'TODO'
          property :date, type: :string, example: 'TODO'
          property :details, type: :object, example: 'TODO'
        end
      end
    end
  end
end
