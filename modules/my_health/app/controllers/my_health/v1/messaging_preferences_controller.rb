# frozen_string_literal: true

module MyHealth
  module V1
    class MessagingPreferencesController < SMController
      def show
        resource = client.get_preferences
        render json: MessagingPreferenceSerializer.new(resource)
      end

      # Set secure messaging email notification preferences.
      # @param email_address - the target email address
      # @param frequency - one of 'none', 'each_message', or 'daily'
      def update
        resource = client.post_preferences(params.permit(:email_address, :frequency))
        render json: MessagingPreferenceSerializer.new(resource)
      end

      # Update preferredTeam value for a patient's list of triage teams
      # @param updated_triage_teams - an array of objects with triage_team_id and preferred_team values
      def update_triage_team_preferences
        updated_triage_teams = Array(params[:updated_triage_teams])

        if updated_triage_teams.empty? || updated_triage_teams.all? do |team|
          preferred_team_value = team[:preferred_team].to_s
          preferred_team_value == 'false'
        end
          raise Common::Exceptions::BadRequest.new(
            detail: 'Invalid input: updated_triage_teams cannot be empty or have all preferred_team values set to false'
          )
        end

        sanitized_triage_teams = updated_triage_teams.map do |team|
          team.permit(:triage_team_id, :preferred_team).to_h
        end
        resource = client.update_triage_team_preferences(sanitized_triage_teams)
        render json: resource
      end

      def signature
        resource = client.get_signature
        render_signature(resource)
      end

      def update_signature
        updated_signature = params.require(:messaging_preference).permit(:signature_name, :signature_title,
                                                                         :include_signature)
        resource = client.post_signature(updated_signature)
        render_signature(resource)
      end

      private

      def render_signature(resource)
        resource[:data] ||= { signature_name: nil, include_signature: false, signature_title: nil }
        render json: MyHealth::V1::MessageSignatureSerializer.new(resource[:data]).to_json
      end
    end
  end
end
