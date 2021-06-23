# frozen_string_literal: true

module FeatureToggles
  ##
  # An object responsible for getting features from the
  # Redis cache or the PostgreSQL db if the cached features
  # are not stored yet in Redis
  #
  # @!attribute cookie_id
  #   @return [String]
  # @!attribute actor
  #   @return [String]
  # @!attribute features
  #   @return [Array]
  # @!attribute current_user
  #   @return [User]
  class Factory
    attr_reader :cookie_id, :actor, :features, :current_user

    ##
    # Builds a FeatureToggles::Factory instance from given options
    #
    # @param opts [Hash]
    #
    # @return [FeatureToggles::Factory] an instance of this class
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
    # Return an array of `all` va.gov features or
    # return a `subset` of them based on the features
    # params that was passed to the API from the UI
    #
    # @return [Array]
    #
    def list
      features.blank? ? all : subset
    end

    ##
    # Return an array of `all` va.gov features
    #
    # @return [Array]
    #
    def all
      features_hash.each_with_object([]) do |(name, values), acc|
        type = values.fetch('actor_type')
        status = enabled?(name, type)

        acc << body(name.camelize(:lower), status)
        acc << body(name, status)
      end
    end

    ##
    # Return a subset of va.gov features based
    # on the features params that was passed
    # to the API from the UI
    #
    # @return [Array]
    #
    def subset
      features.each_with_object([]) do |name, acc|
        name = name.underscore
        type = features_hash.dig(name, 'actor_type')
        status = enabled?(name, type)

        acc << body(name.camelize(:lower), status)
        acc << body(name, status)
      end
    end

    ##
    # Return true or false based on if the feature
    # was enabled via the Flipper UI or if the feature
    # was toggled programmatically
    #
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
    # @return [Flipper::Actor, User]
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
