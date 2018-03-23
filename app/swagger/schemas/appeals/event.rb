# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class Event
        include Swagger::Blocks

        swagger_schema :Event do
          property :type, type: :string, enum: %w[
            claim_decision nod soc form9 ssoc certified hearing_held hearing_cancelled
            hearing_no_show bva_decision field_grant withdrawn ftr ramp death
            merged record_designation reconsideration vacated other_close cavc_decision
            ramp_notice transcript remand_return dro_hearing_held dro_hearing_cancelled
            dro_hearing_no_show
          ], example: 'claim_decision'
          property :date, type: :string, example: '2008-04-24'
          property :details, type: :object, example: ''
        end
      end
    end
  end
end
