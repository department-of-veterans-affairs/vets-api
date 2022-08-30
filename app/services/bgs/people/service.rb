# frozen_string_literal: true

module BGS
  module People
    class Service < BaseService
      class VAFileNumberNotFound < StandardError; end

      def find_person_by_participant_id
        raw_response = @service.people.find_person_by_ptcpnt_id(@user.participant_id, @user.ssn)
        report_error(VAFileNumberNotFound.new) if raw_response.blank?
        BGS::People::Response.new(raw_response, status: :ok)
      rescue => e
        report_error(e)
        BGS::People::Response.new(nil, status: :error)
      end
    end
  end
end
