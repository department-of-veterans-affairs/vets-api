# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

module Mobile
  module V0
    class PhonesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def update
        write_to_vet360_and_render_transaction!(
          'telephone',
          phone_params,
          http_verb: 'put'
        )
      end

      private

      def phone_params
        params.permit(
          :id,
          :area_code,
          :country_code,
          :extension,
          :phone_number,
          :phone_type
        )
      end
    end
  end
end
