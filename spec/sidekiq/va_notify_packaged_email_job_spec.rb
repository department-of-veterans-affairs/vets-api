require 'rails_helper'
require 'sidekiq/attr_package'

RSpec.describe VANotify::PackagedEmailJob, type: :job do
  let(:personalisation) { { first_name: "Jane", date_submitted: "May 1, 2024" } }
  let(:email) { "user@example.com" }
  let(:template_id) { "template-id-123" }
  let(:api_key) { "fake-api-key" }
  let(:callback_options) { { callback_metadata: { notification_type: "confirmation" } } }

  before do
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return("http://fakeapi.com")
    allow(Settings.vanotify.services.va_gov).to receive(:api_key).and_return(
      "test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    )
  end

  it "stores and retrieves personalisation securely" do
    Sidekiq::Testing.inline! do
      key = Sidekiq::AttrPackage.create(attrs: { personalisation: personalisation })
      expect(Sidekiq::AttrPackage.find(key)).to eq(attrs: { personalisation: personalisation })

      expect {
        VANotify::PackagedEmailJob.perform_async(email, template_id, key, api_key, callback_options)
      }.to change { Sidekiq::AttrPackage.find(key) }.from(attrs: { personalisation: personalisation }).to(nil)
    end
  end
end
