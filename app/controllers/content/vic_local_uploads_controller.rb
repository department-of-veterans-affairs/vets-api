# frozen_string_literal: true

module Content
  class VICLocalUploadsController < ApplicationController
    skip_before_action :authenticate

    # This controller is used for simulating the reverse proxy
    # photo upload retreival for VIC development. Do not use this
    # in production code
    # :nocov:
    def find_file
      if Rails.env.development?
        filepath = Rails.root.join('public', sanitize(params[:path]))
        send_file(filepath, disposition: 'inline')
      end
    end

    private

    # https://stackoverflow.com/questions/1939333/how-to-make-a-ruby-string-safe-for-a-filesystem
    def sanitize(filepath)
      filepath.strip do |name|
        # NOTE: File.basename doesn't work right with Windows paths on Unix
        # get only the filename, not the whole path
        name.gsub!(%r{/^.*(\\|\/)/}, '')

        # Strip out the non-ascii character
        name.gsub!(/[^0-9A-Za-z.\-]/, '_')
      end
    end
    # :nocov:
  end
end
