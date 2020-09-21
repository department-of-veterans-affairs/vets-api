class OktaApplication
  def initialize(app)
    @id = app['id']
    @name = app['label']
    @icon_url = app['_links']['logo'][0]['href']
    @permissions = app['permissions'] || []
    # Data source for these still needs to be sourced since most of these are manually put in confluence
    # setting default since there is no types other than third party oauth apps in production
    @type = 'Third Party OAuth'
    @service_categories = []
    @app_url = ''
    @platforms = '' || []
    @description = ''
    @privacy_url = ''
    @tos_url = ''
  end
end
