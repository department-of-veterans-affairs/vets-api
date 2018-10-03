require 'json'

module V0
  module TimeOfNeed
    class TimeOfNeedSubmissionController < TimeOfNeedController
      def create
        form = ::TimeOfNeed::TimeOfNeedSubmission.new(time_of_need_form_params)
        json = JSON.parse(form.to_json.camelize(:lower))
        json.delete_if {|k, v| v.nil?}
        response = Hash.new
        response["newCase"] = json
        response["salesforce_id"] = client.create(response)
        render json: response
      end

      private

      # need to restrict params
      def time_of_need_form_params
        params.require('new_case').permit(
          :burial_activity_type,
          :remains_type,
          :emblem_code,
          :subsequent_indicator,
          :liner_type,
          :liner_size,
          :cremains_type,
          :cemetery_type
        )
      end
    end
  end
end
