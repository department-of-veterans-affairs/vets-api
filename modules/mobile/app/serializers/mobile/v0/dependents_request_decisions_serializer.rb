# frozen_string_literal: true

module Mobile
  module V0
    class DependentsRequestDecisionsSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :dependents_request_decisions

      attribute :dependency_verifications
      attribute :diaries
      attribute :prompt_renewal

      def initialize(user_uuid, drd_info)
        resource = DependentsRequestDecisionsStruct.new(
          id: user_uuid,
          dependency_verifications: Array.wrap(drd_info[:dependency_decs]).map do |a|
                                      a.except(:social_security_number)
                                    end,
          diaries: Array.wrap(drd_info[:diaries]),
          prompt_renewal: prompt_renewal(drd_info)
        )

        super(resource)
      end

      private

      def prompt_renewal(drd_info)
        Array.wrap(drd_info[:diaries]).any? do |diary_entry|
          diary_entry[:diary_lc_status_type] == 'PEND' &&
            diary_entry[:diary_reason_type] == '24' &&
            diary_entry[:diary_due_date] < 7.years.from_now
        end
      end
    end

    DependentsRequestDecisionsStruct = Struct.new(:id, :dependency_verifications, :diaries, :prompt_renewal)
  end
end
