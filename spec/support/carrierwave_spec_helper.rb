# frozen_string_literal: true

# https://github.com/carrierwaveuploader/carrierwave/wiki/How-to:-Cleanup-after-your-Rspec-tests
# https://gist.github.com/gbpereira/c065097865a96db65973
Dir["#{Rails.root}/app/uploaders/*.rb"].each { |file| require file }
if defined?(CarrierWave)
  CarrierWave::Uploader::Base.descendants.each do |klass|
    next if klass.anonymous?
    klass.class_eval do
      def cache_dir
        "#{Rails.root}/spec/support/uploads/tmp"
      end

      def store_dir
        "#{Rails.root}/spec/support/uploads/"
      end
    end
  end
end
