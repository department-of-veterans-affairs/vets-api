# frozen_string_literal: true

require 'va_profile/communication/service'

module V0
  module Profile
    class CommunicationPreferencesController < ApplicationController
      before_action { authorize :vet360, :access? }

      def index
        render text: 'OK'
      end

      def service
        VAProfile::Communication::Service.new(current_user)
      end
    end
  end
end
