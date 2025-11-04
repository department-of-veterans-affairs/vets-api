# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/monitor'
require 'accredited_representative_portal/notification_callback'

require 'lib/veteran_facing_services/notification_callback/shared/saved_claim'

RSpec.describe AccreditedRepresentativePortal::NotificationCallback do
  let(:saved_claim) { create(:saved_claim_benefits_intake) }

  let(:monitor) { instance_double(AccreditedRepresentativePortal::Monitor, track: nil) }

  let(:metadata) do
    {
      form_id: saved_claim.form_id,
      email_template_id: 'template-id',
      email_type: 'error',
      service_name: 'accredited-representative-portal'
      # no saved_claim_id needed because we’ll stub it
    }
  end

  before do
    allow(AccreditedRepresentativePortal::Monitor)
      .to receive(:new).with(claim: saved_claim)
      .and_return(monitor)

    allow(AccreditedRepresentativePortal::NotificationCallback)
      .to receive(:new)
      .and_wrap_original do |original_method, *args|
        callback = original_method.call(*args)
        allow(callback).to receive(:claim).and_return(saved_claim)
        callback
      end

    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
  end

  it_behaves_like 'a SavedClaim Notification Callback',
                  AccreditedRepresentativePortal::NotificationCallback,
                  AccreditedRepresentativePortal::Monitor
end
