# frozen_string_literal: true
module V0
  class IdCardAnnouncementSubscriptionController < ApplicationController
    skip_before_action :authenticate

    def create
      @subscription = IdCardAnnouncementSubscription.find_or_create_by(filtered_params)

      if @subscription.valid?
        render json: { status: 'OK' }, status: :accepted
      else
        raise Common::Exceptions::ValidationErrors, @subscription
      end
    end

    private

    def filtered_params
      params.require(:id_card_announcement_subscription).permit(:email)
    end
  end
end
