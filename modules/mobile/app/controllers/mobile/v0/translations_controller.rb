# frozen_string_literal: true

module Mobile
  module V0
    class TranslationsController < ApplicationController
      skip_before_action :authenticate

      def download
        if needs_translations?
          response.headers['Content-Version'] = file_md5
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

      def file_md5
        @file_md5 ||= Digest::MD5.file(file).hexdigest
      end

      def needs_translations?
        params[:current_version] != file_md5
      end
    end
  end
end
