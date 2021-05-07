# frozen_string_literal: true

module VAOS
  module V2
    class SlotsSerializer
      include FastJsonapi::ObjectSerializer

      set_id :id

      attributes :start,
                 :end
    end
  end
end
