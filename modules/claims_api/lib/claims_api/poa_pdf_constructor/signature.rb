# frozen_string_literal: true

module ClaimsApi
  module PoaPdfConstructor
    class Signature
      attr_reader :data, :x, :y, :height

      def initialize(data:, x:, y:, height: 20)
        @data = data
        @x = x
        @y = y
        @height = height
      end

      def path
        return @path if @path.present?

        @path = "#{::Common::FileHelpers.random_file_path}.png"
        File.open(@path, 'wb') do |f|
          f.write(Base64.decode64(@data))
        end

        @path
      end
    end
  end
end
