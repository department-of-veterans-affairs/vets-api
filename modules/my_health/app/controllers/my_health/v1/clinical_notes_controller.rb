# frozen_string_literal: true

module MyHealth
  module V1
    class ClinicalNotesController < MrController
      def index
        resource = client.list_clinical_notes
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end

      def show
        note_id = params[:id].try(:to_i)
        resource = client.get_clinical_note(note_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end
    end
  end
end
