# frozen_string_literal: true

module OktaRedis
  class App < Model
    CLASS_NAME = 'AppService'
    REDIS_CONFIG_KEY = :okta_response_app
    attr_accessor :grants

    def initialize(attributes = {}, persisted = false)
      super(attributes, persisted)
      @grants = []
    end

    %i[id label].each do |body_attr|
      define_method body_attr do
        okta_response.body[body_attr.to_s]
      end
    end

    alias title label

    def logo
      okta_response.body['_links']['logo'].last['href']
    end

    # rubocop:disable Rails/FindEach
    def fetch_grants
      raise 'Requires user set!' unless @user

      @user.okta_grants.all.each do |grant|
        links = grant['_links']
        app_id = links['app']['href'].split('/').last
        @grants << grant if app_id == @id
      end

      @grants
    end
    # rubocop:enable Rails/FindEach

    def delete_grants
      raise 'Requires user set!' unless @user

      fetch_grants if @grants.length.zero?
      @user.okta_grants.delete_grants(
        @grants.map { |grant| grant['id'] }
      )
    end

    private

    def okta_response
      do_cached_with(key: cache_key) do
        app_response = service.app(@id)
        app_response.success? ? app_response : {}
      end
    end
  end
end
