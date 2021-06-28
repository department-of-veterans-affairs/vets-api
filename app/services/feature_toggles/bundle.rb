# frozen_string_literal: true

module FeatureToggles
  ##
  # An object responsible for getting features from the
  # Redis cache or the PostgreSQL db if the feature_toggles
  # request is not cached
  #
  # @!attribute cookie_id
  #   @return [String]
  # @!attribute actor
  #   @return [String]
  # @!attribute features
  #   @return [Array]
  # @!attribute current_user
  #   @return [User]
  class Bundle
    KEY_PREFIX = 'flippers'

    attr_reader :cookie_id, :actor, :features, :current_user

    ##
    # Builds a FeatureToggles::Bundle instance from given options
    #
    # @param opts [Hash]
    # @return [FeatureToggles::Bundle] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @cookie_id = opts[:cookie_id]
      @actor = Flipper::Actor.new(cookie_id) if cookie_id.present?
      @features = opts[:features]&.split(',')
      @current_user = opts[:user]
    end

    ##
    # Return an array of va.gov features based on the
    # features params that was passed to the endpoint
    #
    # @return [Array]
    #
    def fetch
      return nil if features.blank?

      features.each_with_object([]) do |name, acc|
        type = features_hash.dig(name, 'actor_type')
        status = enabled?(name, type)

        acc << body(name, status)
      end
    end

    ##
    # Return a hexdigest of the combined features
    # so that our Redis key remains short and unique
    #
    # @return [String]
    #
    def redis_key
      return if features.blank?

      joined = features&.sort&.join('_')
      suffix = Digest::SHA1.hexdigest(joined)

      "#{KEY_PREFIX}/#{suffix}"
    end

    ##
    # Return true or false based on if the feature
    # was enabled via the Flipper UI or if the feature
    # was toggled programmatically
    #
    # @param name [String]
    # @param type [String]
    # @return [Boolean]
    #
    def enabled?(name, type)
      Flipper.enabled?(name, actor_type(type))
    end

    ##
    # Return a hash which in this case represents
    # the basic data structure of the feature
    # returned to the caller
    #
    # @param name [String]
    # @param status [Boolean]
    # @return [Hash]
    #
    def body(name, status)
      { name: name, value: status }
    end

    ##
    # Return an instance of Flipper::Actor if the
    # feature is to be accessed by `cookie_id` or return
    # the currently logged in user if the feature's actor
    # is set to `user`
    #
    # @param type [String]
    # @return [Flipper::Actor, User, nil]
    #
    def actor_type(type)
      case type
      when 'cookie_id'
        actor
      when 'user'
        current_user
      end
    end

    ##
    # Return a hash of all features that were
    # added to the `features.yml` file
    #
    # @return [Hash]
    #
    def features_hash
      FLIPPER_FEATURE_CONFIG.fetch('features', {})
    end
  end
end
