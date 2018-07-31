# frozen_string_literal: true

require 'common/client/base'

module Facilities
  # Core class responsible for api interface operations
  class PPMSClient < Common::Client::Base
    configuration Facilities::PPMSConfiguration
    def test_routes(command, params)
      response = perform(:get, command, params)
      response.body
    end

    def provider_locator(params)
      Rails.logger.info('building params')
      qparams = build_params(params)
      Rails.logger.info('built params')
      response = perform(:get, 'ProviderLocator?', qparams)
      Rails.logger.info(response.body)
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
      Rails.logger.info(radius)
      { Address: '22033', Radius: radius, SpecialtyCode: '0',
        Network: 0, Gender: 0, PrimaryCare: true, AcceptingNewPatients: true }
    end
  end
end
