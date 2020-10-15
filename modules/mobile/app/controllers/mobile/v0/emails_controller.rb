# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

module Mobile
  module V0
    class EmailsController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def update
        write_to_vet360_and_render_transaction!(
          'email',
          email_address_params,
          http_verb: 'put'
        )
      end

      private

      def email_address_params
        params.permit(
          :email_address,
          :effective_start_date,
          :id,
          :source_date,
          :transaction_id,
          :vet360_id
        )
      end
    end
  end
end
