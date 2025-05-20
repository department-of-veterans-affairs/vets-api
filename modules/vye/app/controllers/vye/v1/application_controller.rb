# frozen_string_literal: true

module Vye
  module V1
    class ApplicationController < Vye::ApplicationController
      attr_reader :user_info

      before_action :load_user_info

      after_action :verify_authorized

      private

      def load_user_info
        @user_info = Vye::UserProfile.find_and_update_icn(user: current_user)&.active_user_info
      end
    end
  end
end
