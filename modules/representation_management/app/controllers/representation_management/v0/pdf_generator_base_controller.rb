# frozen_string_literal: true

module RepresentationManagement
  module V0
    class PdfGeneratorBaseController < ApplicationController
      service_tag 'lighthouse-veteran' # Is this the correct service tag?
      skip_before_action :authenticate
      before_action :feature_enabled

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:appoint_a_representative_enable_pdf)
      end
    end
  end
end
