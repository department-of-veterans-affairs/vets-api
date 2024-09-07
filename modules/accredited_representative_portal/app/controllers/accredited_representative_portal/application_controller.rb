# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable

    service_tag 'accredited-representative-portal' # ARP DataDog monitoring: https://bit.ly/arp-datadog-monitoring
    validates_access_token_audience Settings.sign_in.arp_client_id

    before_action :verify_pilot_enabled_for_user

    private

    def verify_pilot_enabled_for_user
      unless Flipper.enabled?(:accredited_representative_portal_pilot, @current_user)
        message = 'The accredited_representative_portal_pilot feature flag is disabled ' \
                  "for the user with uuid: #{@current_user.uuid}"

        raise Common::Exceptions::Forbidden, detail: message
      end
    end

    def in_progress_forms_for_user
      InProgressForm.submission_pending.where(user_uuid: @current_user.uuid)
    end

    def form_for_user(form_id)
      return unless @current_user

      in_progress_forms_for_user.find_by(form_id:)
    end
  end
end
