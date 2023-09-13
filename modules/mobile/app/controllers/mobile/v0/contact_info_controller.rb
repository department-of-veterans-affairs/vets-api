# frozen_string_literal: true

module Mobile
  module V0
    class ContactInfoController < ApplicationController
      def show
        render json: Mobile::V0::ContactInfoSerializer.new(@current_user.id, @current_user.vet360_contact_info)
      end
    end
  end
end
