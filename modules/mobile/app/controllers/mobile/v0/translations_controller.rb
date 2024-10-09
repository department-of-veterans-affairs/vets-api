# frozen_string_literal: true

module Mobile
  module V0
    class TranslationsController < ApplicationController
      skip_before_action :authenticate

      def show
        last_downloaded = params[:last_downloaded]&.to_i
        if last_downloaded.nil? || (last_downloaded.to_i < file_last_changed)
          send_file(
            file,
            type: 'application/json',
            filename: 'common.json',
            disposition: 'attachment'
          )
        else
          render status: :ok
        end
      end

      private

      def file
        Rails.root.join('modules', 'mobile', 'app', 'assets', 'translations', 'en', 'common.json')
      end

      def file_last_changed
        file.mtime.to_i
      end
    end
  end
end
