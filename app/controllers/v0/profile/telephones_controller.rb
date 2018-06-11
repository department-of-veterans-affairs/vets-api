# frozen_string_literal: true

module V0
  module Profile
    class TelephonesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def create
        write_to_vet360_and_render_transaction!('telephone', delete_safety_catch(telephone_params))
      end

      def update
        write_to_vet360_and_render_transaction!('telephone', delete_safety_catch(telephone_params), http_verb: 'put')
      end

      def destroy
        write_to_vet360_and_render_transaction!('telephone', delete_safety_catch(telephone_params), http_verb: 'put')
      end

      private

      def telephone_params
        params.permit(
          :area_code,
          :country_code,
          :extension,
          :effective_start_date,
          :effective_end_date,
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
