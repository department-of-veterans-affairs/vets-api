# frozen_string_literal: true

module V0
  module Profile
    class CommunicationPreferencesController < ApplicationController
      before_action { authorize :vet360, :access? }

      def index
      end

      def service
        VAProfile::Communication::Service.new(current_user)
      end
    end
  end
end
