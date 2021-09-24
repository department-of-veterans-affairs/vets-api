# frozen_string_literal: true

require 'date'

module V0
  module VirtualAgent
    class VirtualAgentAppealController < AppealsBaseController
      def index
        # @appeal_status_description
        appeals_response = appeals_service.get_appeals(current_user)
        appeals_data_array = appeals_response.body['data']
        data = data_for_first_comp_appeal(appeals_data_array)
        render json: {
          data: data
        }
      end

      def data_for_first_comp_appeal(appeals)
        comp_appeal = first_open_comp_appeal(appeals)

        return [] if comp_appeal.nil?

        [transform_appeal_to_response(comp_appeal)]
      end

      def transform_appeal_to_response(appeal)
        aoj = appeal['attributes']['aoj']
        {
          appeal_type: appeal['attributes']['programArea'].capitalize,
          filing_date: get_earliest_event_date(appeal).strftime('%m/%d/%Y'),
          appeal_status: get_status_type_text(appeal['attributes']['status']['type'], aoj)
        }
      end

      def first_open_comp_appeal(appeals)
        appeals
          .sort_by { |appeal| get_earliest_event_date appeal }
          .reverse
          .find { |appeal| open_compensation? appeal }
      end

      def get_earliest_event_date(appeal)
        events = appeal['attributes']['events']
        DateTime.parse events
          .min_by { |event| DateTime.parse event['date'] }['date']
      end

      def open_compensation?(appeal)
        appeal['attributes']['programArea'] == 'compensation' and appeal['attributes']['active']
      end

      APPEAL_DESCRIPTIONS = {
        'pending_soc' => 'A Decision Review Officer is reviewing your appeal',
        'pending_form9' => 'Please review your Statement of the Case',
        'pending_certification' => 'The Decision Review Officer is finishing their review of your appeal',
        'pending_certification_ssoc' => 'Please review your Supplemental Statement of the Case',
        'remand_ssoc' => 'Please review your Supplemental Statement of the Case',
        'pending_hearing_scheduling' => 'You’re waiting for your hearing to be scheduled',
        'scheduled_hearing' => 'Your hearing has been scheduled',
        'on_docket' => 'Your appeal is waiting to be sent to a judge',
        'at_vso' => 'Your appeal is with your Veterans Service Organization',
        'decision_in_progress' => 'A judge is reviewing your appeal',
        'bva_development' => 'The judge is seeking more information before making a decision',
        'stayed' => 'The Board is waiting until a higher court makes a decision',
        'remand' => 'The Board made a decision on your appeal',
        'ama_remand' => 'The Board made a decision on your appeal',
        'bva_decision' => 'The Board made a decision on your appeal',
        'field_grant' => 'The {aoj_desc} granted your appeal',
        'withdrawn' => 'You withdrew your appeal',
        'ftr' => 'Your appeal was closed',
        'ramp' => 'You opted in to the Rapid Appeals Modernization Program (RAMP)',
        'reconsideration' => 'Your Motion for Reconsideration was denied',
        'death' => 'The appeal was closed',
        'other_close' => 'Your appeal was closed',
        'merged' => 'Your appeal was merged',
        'statutory_opt_in' => 'You requested a decision review under the Appeals Modernization Act',
        'evidentiary_period' => 'Your appeals file is open for new evidence',
        'post_bva_dta_decision' => 'The {aoj_desc} corrected an error',
        'bva_decision_effectuation' => 'The {aoj_desc} corrected an error',
        'sc_received' => 'A reviewer is examining your new evidence',
        'hlr_received' => 'A senior reviewer is taking a new look at your case',
        'sc_decision' => 'The {aoj_desc} made a decision',
        'hlr_decision' => 'The {aoj_desc} made a decision',
        'hlr_dta_error' => 'The {aoj_desc} is correcting an error',
        'sc_closed' => 'Your Supplemental Claim was closed',
        'hlr_closed' => 'Your Higher-Level Review was closed',
        'remand_return' => 'Your appeal was returned to the Board of Veterans’ Appeals'
      }.freeze

      AOJ_DESCRIPTIONS = { 'vba' => 'Veterans Benefits Administration',
                           'vha' => 'Veterans Health Administration',
                           'nca' => 'National Cemetery Administration',
                           'other' => 'Agency of Original Jurisdiction' }.freeze

      def get_status_type_text(appeal_status, aoj)
        appeal_status_description = APPEAL_DESCRIPTIONS[appeal_status]

        if appeal_status_description.include? '{aoj_desc}'
          appeal_status_description.gsub('{aoj_desc}', AOJ_DESCRIPTIONS[aoj])
        else
          appeal_status_description
        end
      end
    end
  end
end
