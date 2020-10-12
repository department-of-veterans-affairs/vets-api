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
          :area_code,
          :country_code,
          :extension,
          :effective_start_date,
          :id,
          :is_international,
          :is_textable,
          :is_text_permitted,
          :is_tty,
          :is_voicemailable,
          :phone_number,
          :phone_type,
          :source_date,
          :transaction_id,
          :vet360_id
        )
      end
    end
  end
end
