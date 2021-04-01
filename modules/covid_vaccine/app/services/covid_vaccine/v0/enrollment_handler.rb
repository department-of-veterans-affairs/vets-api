# frozen_string_literal: true

module CovidVaccine
  module V0
    class EnrollmentHandler
      SERVICE_NAME = 'CovidVaccine::EnrollmentService'

      def on_open(_uploader, file)
        Rails.logger.info "#{SERVICE_NAME} starting upload: #{file.local} -> #{file.remote} (#{file.size} bytes)"
      end

      def on_put(_uploader, file, offset, data)
        Rails.logger.info "#{SERVICE_NAME} writing #{data.length} bytes to #{file.remote} starting at #{offset}"
      end

      def on_close(_uploader, file)
        Rails.logger.info "#{SERVICE_NAME} finished with #{file.remote}"
      end

      def on_mkdir(_uploader, path)
        Rails.logger.info "#{SERVICE_NAME} creating directory #{path}"
      end

      def on_finish(_uploader)
        Rails.logger.info "#{SERVICE_NAME} all done!"
      end
    end
  end
end
