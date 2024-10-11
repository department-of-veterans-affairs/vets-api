# frozen_string_literal: true

module Mobile
  module V0
    class TranslationsController < ApplicationController
      skip_before_action :authenticate

      def download
        if params[:current_version].nil? || (Integer(params[:current_version]) < file_last_changed)
          response.headers['Content-Version'] = file_last_changed
          send_file(
            file,
            type: 'application/json',
            filename: 'common.json',
            disposition: 'attachment'
          )
        else
          head :no_content
        end
      end

      private

      def file
        Rails.root.join('modules', 'mobile', 'app', 'assets', 'translations', 'en', 'common.json')
      end

      def file_last_changed
        @file_last_changed ||= begin
          # can't interpolate file path into system call because it violates a security rule
          timestamp = `git log -1 --format='%ct' -- modules/mobile/app/assets/translations/en/common.json`
          Integer(timestamp)
        end
      end
    end
  end
end
