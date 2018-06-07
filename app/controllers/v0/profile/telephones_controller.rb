# frozen_string_literal: true

module V0
  module Profile
    class TelephonesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!('telephone', telephone_params)
      end

      def update
        write_to_vet360_and_render_transaction!('telephone', telephone_params, http_verb: 'put')
      end

      def destroy
        write_to_vet360_and_render_transaction!('telephone', telephone_params, http_verb: 'put')
      end

      private

      def telephone_params

        accepted_fields = [ 
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
        ]
        
        if (request_is_delete?)
          params[:effective_end_date] = Time.now.utc.iso8601
          accepted_fields << :effective_end_date
        end

        params.permit(
          accepted_fields
        )
      end
    end
  end
end
