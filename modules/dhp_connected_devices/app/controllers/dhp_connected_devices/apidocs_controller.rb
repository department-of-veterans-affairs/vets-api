# frozen_string_literal: true

module DhpConnectedDevices
  class ApidocsController < ApplicationController
    skip_before_action :authenticate

    def index
      swagger = YAML.safe_load(File.read(DhpConnectedDevices::Engine.root.join('app/docs/dhp_connected_devices.yaml')))

      render json: swagger
    end
  end
end
