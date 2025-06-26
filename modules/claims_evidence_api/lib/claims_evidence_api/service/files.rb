# frozen_string_literal: true

require 'claims_evidence_api/service/base'

module ClaimsEvidenceApi
  module Service

    # Files API
    class Files < Base

      def create(file_path, provider_data:)
        headers = {'X-Folder-URI': x_folder_uri}
        params = post_params(file_path, provider_data)

        perform :post, 'files', params, headers
      end
      alias upload create

      def read(uuid, include_raw_text: false)
        perform :get, "files/#{uuid}?includeRawTextData=#{include_raw_text}", {}, {}
      end
      alias retrieve read

      def update(uuid, provider_data:)
        perform :put, "files/#{uuid}", provider_data.to_json, {}
      end

      def overwrite(uuid, file_path, provider_data:)
        headers = {'X-Folder-URI': x_folder_uri}
        params = post_params(file_path, provider_data)

        perform :post, "files/#{uuid}", params, headers
      end

      private

      def post_params(file_path, provider_data)
        file_name = File.basename(file_path)
        mime_type = Marcel::MimeType.for(file_path)

        params = {
          payload: {
            contentName: file_name,
            providerData: provider_data
          },
          file: Faraday::UploadIO.new(file_path, mime_type, file_name)
        }
      end

      # end Files
    end

    # end Service
  end

  # end ClaimsEvidenceApi
end
