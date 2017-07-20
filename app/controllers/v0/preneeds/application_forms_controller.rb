# frozen_string_literal: true
module V0
  module Preneeds
    class ApplicationFormsController < PreneedsController
      def new
        form_fill = ::Preneeds::FormFill.new

        # TODO: Getting military ranks for all branches of service is slow, even when cached. Perhaps
        # Rely on the military_ranks controller, which the FE would call when the user selects a branch of service.
        # form_fill.military_ranks = form_fill.branches_of_services.each_with_object({}) do |branch, hash|
        #   rank_params = ::Preneeds::MilitaryRankInput.new(
        #     branch_of_service: branch.id,
        #     start_date: branch.begin_date,
        #     end_date: branch.end_date || Time.now.utc
        #   )
        #   hash[branch.id] = client.get_military_rank_for_branch_of_service(rank_params.to_h)
        # end

        render json: form_fill, serializer: ::Preneeds::FormFillSerializer
      end

      def create
        application_form = ::Preneeds::ApplicationForm.new(application_form_params)
        raise Common::Exceptions::ValidationErrors, application_form unless application_form.valid?

        resource = client.receive_pre_need_application(application_form.message)
        render json: resource, serializer: ::Preneeds::ReceiveApplicationSerializer
      end

      private

      def application_form_params
        params.require(:pre_need_request)
              .permit(
                :application_status, :has_attachments, :has_currently_buried, :sending_code,
                applicant: ::Preneeds::Applicant.permitted_params,
                claimant: ::Preneeds::Claimant.permitted_params,
                currently_buried_persons: [::Preneeds::CurrentlyBuried.permitted_params],
                veteran: ::Preneeds::Veteran.permitted_params
              )
      end
    end
  end
end
