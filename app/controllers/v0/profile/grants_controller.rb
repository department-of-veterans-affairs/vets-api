# frozen_string_literal: true

module V0
  module Profile
    class GrantsController < ApplicationController
      def index
        grants_response = Okta::Service.new.grants(@current_user.uid)
        if grants_response.success?
          @grants = grants_response.body
        else
          log_message_to_sentry('Error retrieving grants for user', :error,
                                body: profile_response.body)
          raise 'Unable to retrieve grants for user'
        end
        render json: @grants
      end

      def destroy
        delete_response = Okta::Service.new.delete_grant(@current_user.uid, grants_params[:id])       
        if delete_response.success?
          head :no_content
        else
          log_message_to_sentry("Error deleting grant #{grants_params[:id]}", :error,
                                body: delete_response.body)
          raise 'Unable to delete grant'
        end

      end
      
      private

      def grants_params
        params.require(:id)
      end
    end
  end
end