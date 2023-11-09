# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class MrSessionController < MrController
        def create
          client
          head :no_content
        end
      end
    end
  end
end
