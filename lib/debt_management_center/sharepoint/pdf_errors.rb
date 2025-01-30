# frozen_string_literal: true

module DebtManagementCenter
  module Sharepoint
    class PdfErrors < Faraday::Middleware
      def on_complete(env)
        return if env.success?

        # upload: /sites/vhafinance/MDW/_api/Web/GetFolderByServerRelativeUrl('""
        # get list: "/sites/vhafinance/MDW/_api/Web/GetFileByServerRelativePath(decodedurl='"
        # update list: /sites/vhafinance/MDW/_api/Web/Lists
        Rails.logger.error("Sharepoint failed path: #{env.url.path[/.*\/Web\/[^\/]+/]}", env.body)
        response_values = { status: env.status, detail: response_detail(env), source: 'SharepointRequest' }
        case env.status
        when 400..499
          raise Common::Exceptions::BackendServiceException.new(
            'SHAREPOINT_PDF_400', response_values.merge(code: 'SHAREPOINT_PDF_400'), env.status, env.body
          )
        when 500..510
          raise Common::Exceptions::BackendServiceException.new(
            'SHAREPOINT_PDF_502', response_values.merge(code: 'SHAREPOINT_PDF_502'), env.status, env.body
          )
        else
          raise Common::Exceptions::BackendServiceException.new(
            'SHAREPOINT_PDF_UNKNOWN', response_values.merge(code: 'SHAREPOINT_PDF_UNKNOWN'), env.status, env.body
          )
        end
      end

      def response_detail(env)
        env.reason_phrase
      end
    end
  end
end
