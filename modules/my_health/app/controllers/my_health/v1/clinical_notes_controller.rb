# frozen_string_literal: true

module MyHealth
  module V1
    class ClinicalNotesController < MRController
      def index
        render_resource client.list_clinical_notes
      end

      def show
        note_id = params[:id].try(:to_i)
        render_resource client.get_clinical_note(note_id)
      end
    end
  end
end
