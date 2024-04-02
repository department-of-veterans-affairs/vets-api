module Analytics
  module V0
    class HashesController < ApplicationController
      def index
        data = { hello: 'world' }
        render json: data
      end
    end
  end
end
