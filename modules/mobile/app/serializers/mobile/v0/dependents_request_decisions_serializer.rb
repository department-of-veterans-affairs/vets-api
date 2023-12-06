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
          dependency_verifications: dependency_verifications(drd_info[:dependency_decs]),
          diaries: diaries(drd_info[:diaries]),
          prompt_renewal: prompt_renewal(drd_info)
        )

        super(resource)
      end

      private

      # rubocop:disable Metrics/MethodLength
      def dependency_verifications(deps)
        Array.wrap(deps).map do |dep|
          {
            award_effective_date: dep[:award_effective_date],
            award_event_id: dep[:award_event_id],
            award_type: dep[:award_type],
            begin_award_event_id: dep[:begin_award_event_id],
            beneficiary_id: dep[:beneficiary_id],
            birthday_date: dep[:birthday_date],
            decision_date: dep[:decision_date],
            decision_id: dep[:decision_id],
            dependency_decision_id: dep[:dependency_decision_id],
            dependency_decision_type: dep[:dependency_decision_type],
            dependency_decision_type_description: dep[:dependency_decision_type_description],
            dependency_status_type: dep[:dependency_status_type],
            dependency_status_type_description: dep[:dependency_status_type_description],
            event_date: dep[:event_date],
            first_name: dep[:first_name],
            full_name: dep[:full_name],
            last_name: dep[:last_name],
            modified_action: dep[:modified_action],
            modified_by: dep[:modified_by],
            modified_date: dep[:modified_date],
            modified_location: dep[:modified_location],
            modified_process: dep[:modified_process],
            person_id: dep[:person_id],
            relationship_type_description: dep[:relationship_type_description],
            sort_date: dep[:sort_date],
            sort_order_number: dep[:sort_order_number],
            veteran_id: dep[:veteran_id]
          }
        end
      end

      def diaries(diaries)
        Array.wrap(diaries).map do |diary|
          {
            award_diary_id: diary[:award_diary_id],
            award_type: diary[:award_type],
            beneficary_id: diary[:beneficary_id],
            diary_due_date: diary[:diary_due_date],
            diary_lc_status_type: diary[:diary_lc_status_type],
            diary_lc_status_type_description: diary[:diary_lc_status_type_description],
            diary_reason_type: diary[:diary_reason_type],
            diary_reason_type_description: diary[:diary_reason_type_description],
            file_number: diary[:file_number],
            first_nm: diary[:first_nm],
            last_name: diary[:last_name],
            modified_action: diary[:modified_action],
            modified_by: diary[:modified_by],
            modified_date: diary[:modified_date],
            modified_location: diary[:modified_location],
            modified_process: diary[:modified_process],
            ptcpnt_diary_id: diary[:ptcpnt_diary_id],
            payee_type: diary[:payee_type],
            status_date: diary[:status_date],
            veteran_id: diary[:veteran_id]
          }
        end
      end
      # rubocop:enable Metrics/MethodLength

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
