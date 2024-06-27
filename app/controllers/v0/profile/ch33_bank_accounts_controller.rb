# frozen_string_literal: true

require 'bgs/service'

module V0
  module Profile
    class Ch33BankAccountsController < ApplicationController
      service_tag 'direct-deposit'
      before_action :controller_enabled?
      before_action { authorize :ch33_dd, :access? }

      def index
        render_find_ch33_dd_eft
      end

      def update
        res = service.update_ch33_dd_eft(
          params[:financial_institution_routing_number],
          params[:account_number],
          params[:account_type] == 'Checking'
        ).body

        unless res[:update_ch33_dd_eft_response][:return][:return_code] == 'S'
          return render(json: res, status: :bad_request)
        end

        VANotifyDdEmailJob.send_to_emails(current_user.all_emails, 'ch33')

        Rails.logger.warn('Ch33BankAccountsController#update request completed', sso_logging_info)

        render_find_ch33_dd_eft
      end

      private

      def controller_enabled?
        if Flipper.enabled?(:profile_show_direct_deposit_single_form_edu_downtime, @current_user)
          raise Common::Exceptions::Forbidden, detail: 'This endpoint is deprecated and will be removed soon.'
        end
      end

      def render_find_ch33_dd_eft
        get_ch33_dd_eft_info = service.get_ch33_dd_eft_info
        render(
          json: get_ch33_dd_eft_info,
          serializer: Ch33BankAccountSerializer
        )
      end

      def service
        BGS::Service.new(current_user)
      end
    end
  end
end
