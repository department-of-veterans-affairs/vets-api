# frozen_string_literal: true

module AppsApi
  module Apps
    class App
      include Swagger::Blocks

      swagger_component do
        schema :AppsIndex do
          key :description, I18n.t('apps_api.endpoint_descriptions.index')
          property :id do
            key :description, 'JSON API identifier'
            key :type, :string
            key :example, 'VA10192'
          end
          property :type do
            key :description, 'JSON API type specification'
            key :type, :string
            key :example, 'va_form'
          end
          property :attributes do
            property :name do
              key :description, I18n.t('apps_api.field_descriptions.name')
              key :type, :string
              key :example, 'Health App'
            end

            property :description do
              key :description, I18n.t('apps_api.field_descriptions.description')
              key :type, :string
              key :example, 'Example Health is a app to help you manage your healthcare records.'
            end

            property :platform do
              key :description, I18n.t('apps_api.field_descriptions.platform')
              key :type, :string
              key :example, 'Web'
            end

            property :type do
              key :description, I18n.t('apps_api.field_descriptions.type')
              key :type, :string
              key :example, 'Third-Party'
            end

            property :iconURL do
              key :description, I18n.t('apps_api.field_descriptions.iconUrl')
              key :type, :string
              key :example, 'https://www.example.com/static/images/example.png'
            end

            property :categories do
              key :description, I18n.t('apps_api.field_descriptions.categories')
              key :type, :array
              key :example, 'Health'
            end

            property :appURL do
              key :description, I18n.t('apps_api.field_descriptions.appURL')
              key :type, :boolean
              key :example, 'https://www.example.com'
            end

            property :permissions do
              key :description, I18n.t('apps_api.field_descriptions.permissions')
              key :type, :array
              key :example, ['Read Perscription History', 'Read Personal Medical History', 'Family Medical History']
            end
            property :privacyPolicyURL do
              key :description, I18n.t('apps_api.field_descriptions.privacyPolicyURL')
              key :type, :string
              key :example, 'https://www.example.com/privacy'
            end
            property :termsOfServiceURL do
              key :description, I18n.t('apps_api.field_descriptions.termsOfServiceURL')
              key :type, :string
              key :example, 'https://www.example.com/tos'
            end
          end
        end
      end
    end
  end
end
