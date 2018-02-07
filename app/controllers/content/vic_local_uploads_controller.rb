# frozen_string_literal: true

module Content
  class VICLocalUploadsController < ApplicationController
    skip_before_action :authenticate
    # :nocov:
    def find_file
      path = Rails.root.join('public', params[:path])
      send_file(path, disposition: 'inline')
    end
    # :nocov:
  end
end
