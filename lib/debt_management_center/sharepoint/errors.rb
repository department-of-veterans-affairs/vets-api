# frozen_string_literal: true

module DebtManagementCenter
  module Sharepoint
    class Errors < Faraday::Middleware
      def on_complete(env)
        return if env.success?

        case env.status
        when 400..499
          raise Common::Exceptions::BackendServiceException.new('SHAREPOINT_GET_LIST_ITEM_400', source: self.class)
        when 500..510
          raise Common::Exceptions::BackendServiceException.new('SHAREPOINT_GET_LIST_ITEM_502', source: self.class)
        else
          raise Common::Exceptions::BackendServiceException.new('SHAREPOINT_GET_LIST_ITEM_UNKNOWN', source: self.class)
        end
      end
    end
  end
end
