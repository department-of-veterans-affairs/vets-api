# frozen_string_literal: true

module AppsApi
  module Apps
    class App
      include Swagger::Blocks

      swagger_component do
        schema :AppsIndex do
          key :description, I18n.t('apps_api.endpoint_descriptions.index')
          property :id do
            key :description, I18n.t('apps_api.field_descriptions.id')
            key :type, :string
            key :example, '1'
          end
          property :name do
            key :description, I18n.t('apps_api.field_descriptions.name')
            key :type, :string
            key :example, 'Health App'
          end
          property :app_type do
            key :description, I18n.t('apps_api.field_descriptions.app_type')
            key :type, :string
            key :example, 'va_form'
          end
          property :description do
            key :description, I18n.t('apps_api.field_descriptions.description')
            key :type, :string
            key :example, 'Example Health is an app to help you manage your healthcare records.'
          end
          property :platforms do
            key :description, I18n.t('apps_api.field_descriptions.platforms')
            key :type, :string
            key :example, 'Web'
          end
          property :logo_url do
            key :description, I18n.t('apps_api.field_descriptions.logo_url')
            key :type, :string
            key :example, 'https://www.example.com/static/images/example.png'
          end
          property :service_categories do
            key :description, I18n.t('apps_api.field_descriptions.service_categories')
            key :type, :array
            key :example, ['Health']
          end
          property :app_url do
            key :description, I18n.t('apps_api.field_descriptions.app_url')
            key :type, :string
            key :example, 'https://www.example.com'
          end
          property :privacy_url do
            key :description, I18n.t('apps_api.field_descriptions.privacy_url')
            key :type, :string
            key :example, 'https://www.example.com/privacy'
          end
          property :tos_url do
            key :description, I18n.t('apps_api.field_descriptions.tos_url')
            key :type, :string
            key :example, 'https://www.example.com/tos'
          end
        end
      end
    end
  end
end
