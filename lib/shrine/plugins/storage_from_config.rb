# frozen_string_literal: true

require 'shrine/storage/s3'
require 'shrine/storage/file_system'

class Shrine
  module Plugins
    module StorageFromConfig
      def self.configure(uploader, opts = {})
        uploader.opts[:storage_settings] = opts.fetch(:settings, uploader.opts[:settings])
      end

      module ClassMethods
        def find_storage(name)
          storage_from_config(name) || super
        end

        private

        def storage_from_config(name)
          config = opts[:storage_settings]
          @storage_from_config ||= {}
          @storage_from_config[name.to_sym] ||=
            case config.type
            when 'memory'
              Shrine::Storage::Memory.new
            when 'local'
              Shrine::Storage::FileSystem.new('tmp', prefix: File.join('uploads', config.path.to_s, name.to_s))
            when 's3'
              sanitized_config = config.to_h.delete_if { |k, _| k == :type || k == :path || k == :upload_options }
              Shrine::Storage::S3.new(
                bucket: config.bucket,
                prefix: File.join(config.path.to_s, name.to_s),
                upload_options: config[:upload_options],
                **sanitized_config
              )
            end
        end
      end
    end

    register_plugin(:storage_from_config, StorageFromConfig)
  end
end
