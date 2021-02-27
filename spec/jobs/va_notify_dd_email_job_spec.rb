# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotifyDdEmailJob, type: :model do
  let(:email) { 'user@example.com' }

  describe '#perform' do
    %w[ch33 comp_pen].each do |dd_type|
      context "with a dd type of #{dd_type}" do
        it 'sends a confirmation email' do
          client = double
          expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)

          expect(client).to receive(:send_email).with(
            email_address: email,
            template_id: dd_type == 'ch33' ? 'edu_template_id' : 'comp_pen_template_id'
          )

          described_class.new.perform(email, dd_type.to_sym)
        end
      end
    end
  end
end
