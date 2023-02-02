# frozen_string_literal: true

module MyHealth
  module V1
    class ThreadsController < SMController
      def move
        folder_id = params.require(:folder_id)
        client.post_move_thread(params[:id], folder_id)
        head :no_content
      end
    end
  end
end
