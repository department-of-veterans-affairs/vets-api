# frozen_string_literal: true

module DebtManagementCenter
  module Sharepoint
    class PdfErrors < Faraday::Middleware
      def on_complete(env)
        return if env.success?

        case env.status
        when 400..499
          raise Common::Exceptions::BackendServiceException.new('SHAREPOINT_PDF_400', source: self.class)
        when 500..510
          raise Common::Exceptions::BackendServiceException.new('SHAREPOINT_PDF_502', source: self.class)
        else
          raise Common::Exceptions::BackendServiceException.new('SHAREPOINT_PDF_UNKNOWN', source: self.class)
        end
      end
    end
  end
end
