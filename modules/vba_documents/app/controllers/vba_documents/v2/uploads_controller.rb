# frozen_string_literal: true

require 'zip'

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'
require_dependency 'vba_documents/payload_manager'
require 'common/exceptions'

module VBADocuments
  module V2
    class UploadsController < ApplicationController
      skip_before_action(:authenticate)

      def submit
        render json: {empty: :stub}
      end

    end
  end
end
