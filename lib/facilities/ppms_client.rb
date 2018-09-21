# frozen_string_literal: true

require 'common/client/base'

module Facilities
  # Core class responsible for api interface operations
  class PPMSClient < Common::Client::Base
    configuration Facilities::PPMSConfiguration

    def provider_locator(params)
      qparams = build_params(params)
      response = perform(:get, 'v1.0/ProviderLocator?', qparams)
      bbox_num = params[:bbox].map { |x| Float(x) }
      response.body.select! do |provider|
        provider['Latitude'] > bbox_num[1] && provider['Latitude'] < bbox_num[3] &&
          provider['Longitude'] > bbox_num[0] && provider['Longitude'] < bbox_num[2]
      end
      response.body
    end

    def provider_info(identifier)
      qparams = { :$expand => 'ProviderSpecialties' }
      response = perform(:get, "v1.0/Providers(#{identifier})?", qparams)
      response.body[0]
    end

    def specialties
      response = perform(:get, 'v1.0/Specialties', {})
      response.body
    end

    def build_params(params)
      bbox_num = params[:bbox].map { |x| Float(x) }
      lats = bbox_num.values_at(1, 3)
      longs = bbox_num.values_at(2, 0)
      # more estimation fun about 69 miles between latitude lines, <= 69 miles between long lines
      xlen = (lats.max - lats.min) * 69 / 2
      ylen = (longs.max - longs.min) * 69 / 2
      radius = Math.sqrt(xlen * xlen + ylen * ylen) * 1.1 # go a little bit beyond the corner;
      { address: params[:address], radius: radius, driveTime: 10_000, specialtycode1: 'null',
        specialtycode2: 'null', specialtycode3: 'null', specialtycode4: 'null',
        network: 0, gender: 0, primarycare: 0, acceptingnewpatients: 0, maxResults: 200 }
    end
  end
end
