module VANotify
  class PackagedEmailJob
    include Sidekiq::Job

    def perform(email, template_id, attr_package_key, api_key, callback_options = {})
      personalisation = fetch_and_cleanup_personalisation(attr_package_key)
      return unless personalisation

      VaNotify::Service.new(api_key, callback_options).send_email(
        email_address: email,
        template_id: template_id,
        personalisation: personalisation
      )
    end

    def self.enqueue(email, template_id, personalisation, api_key, callback_options = {})
      key = Sidekiq::AttrPackage.create(attrs: { personalisation: personalisation })
      perform_async(email, template_id, key, api_key, callback_options)
    end

    private

    def fetch_and_cleanup_personalisation(attr_package_key)
      attrs = Sidekiq::AttrPackage.find(attr_package_key)
      Sidekiq::AttrPackage.delete(attr_package_key) if attrs
      attrs&.dig(:personalisation)
    end
  end
end
