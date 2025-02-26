require "yaml"
require "ostruct"

module Identity
  class Config
    CONFIG_FILES = %w[sign_in map_services]

    def self.load_config
      @config ||= begin
        hash = {}
        CONFIG_FILES.each do |file|
          path = Rails.root.join("config/identity", "#{file}.yml")
          hash[file.to_sym] = OpenStruct.new(YAML.load_file(path)[Settings.vsp_environment]) if File.exist?(path)
        end
        hash
      end
    end

    def self.method_missing(name, *args, &block)
      load_config
      # binding.pry
      return @config[name] if @config.key?(name)

      super
    end

    def self.respond_to_missing?(name, include_private = false)
      load_config
      @config.key?(name) || super
    end
  end
end

# Example Usage
#-------------------------------------
# Identity::Config.sign_in
#  => #<OpenStruct jwt_encode_key="spec/fixtures/sign_in/privatekey.pem", ...

# Identity::Config.sign_in.jwt_encode_key
#  => "spec/fixtures/sign_in/privatekey.pem"

#  Identity::Config.sign_in.jwt_encode_key = "test"
#  => "test"

#  Identity::Config.map_services.chatbot_client_id
#  => "2bb9803acfc3"
