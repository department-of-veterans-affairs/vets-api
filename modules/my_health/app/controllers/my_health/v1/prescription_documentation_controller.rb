# frozen_string_literal: true

module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      def index
        render json: { error: 'Documentation is not available' }, status: :not_found
      end
    end
  end
end
