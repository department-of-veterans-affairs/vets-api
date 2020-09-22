# frozen_string_literal: true

class OktaApplication
  attr_accessor :id, :name, :logo_url, :permissions, :type,
                :service_categories, :platforms, :app_url,
                :description, :privacy_url, :tos_url

  def initialize(app)
    @id = app['id']
    @name = app['label']
    @logo_url = app['_links']['logo'][0]['href']
    @permissions = app['permissions'] || []
    # Data source for these still needs to be sourced since most of these are manually put in confluence
    # setting default since there is no types other than third party oauth apps in production
    @type = 'Third Party OAuth'
    @service_categories = []
    @platforms = []
    @app_url = ''
    @description = ''
    @privacy_url = ''
    @tos_url = ''
  end
end
