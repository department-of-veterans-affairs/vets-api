# frozen_string_literal: true

require 'bgs/service'
require 'mpi/service'
require 'evss/service'

module ClaimsApi
  module V2
    class OkComputerController < ::OkComputer::OkComputerController
      def index
        mpi = run_check('mpi', MpiCheck)
        ebenefits_benefit_claims_status = run_check('bgs-ebenefits_benefit_claims_status', BgsCheck)
        bgs_intent_to_file = run_check('bgs-intent_to_file', BgsCheck)
        bgs_tracked_items = run_check('bgs-tracked_items', BgsCheck)

        render json: {
          mpi: mpi,
          'bgs-ebenefits_benefit_claims_status': ebenefits_benefit_claims_status,
          'bgs-intent_to_file': bgs_intent_to_file, 'bgs-tracked_items': bgs_tracked_items
        }
      end

      def run_check(check_name, class_name = nil)
        arg = %w[evss mpi].include?(check_name) ? nil : check_name.split('-')[1]
        check = OkComputer::Registry.register check_name, arg.nil? ? class_name.new : class_name.new(arg)
        check.run

        get_display(check)
      end

      def get_display(check)
        display = {}
        display['success'] = !check.failure_occurred
        display['time'] = check.time
        display['message'] = check.message

        display
      end
    end
  end
end
