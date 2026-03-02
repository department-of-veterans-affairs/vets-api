# frozen_string_literal: true

# Shared concern for downloading XLSX files via the GCLAWS XlsxClient.
# Including classes must define a `log_error(message)` method.
module GclawsXlsxDownloader
  extend ActiveSupport::Concern

  private

  # Downloads the accreditation XLSX file and yields its binary content to the caller's block.
  # On failure, logs the error and does not yield.
  #
  # @yield [String] the binary file content
  def with_xlsx_file_content
    RepresentationManagement::GCLAWS::XlsxClient.download_accreditation_xlsx do |result|
      if result[:success]
        yield File.binread(result[:file_path])
      else
        log_error("GCLAWS download failed: #{result[:error]} (status: #{result[:status]})")
      end
    end
  end
end
