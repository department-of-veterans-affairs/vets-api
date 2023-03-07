# frozen_string_literal: true

require 'bgs/service'
require 'mpi/service'
require 'evss/service'

module ClaimsApi
  module V1
    class OkComputerController < ::OkComputer::OkComputerController
      def index
        evss = run_check('evss', EvssCheck)
        mpi = run_check('mpi', MpiCheck)
        bgs_vet_record = run_check('bgs-vet_record', BgsCheck)
        bgs_corporate_update = run_check('bgs-corporate_update', BgsCheck)
        bgs_intent_to_file = run_check('bgs-intent_to_file', BgsCheck)
        bgs_claimant = run_check('bgs-claimant', BgsCheck)
        bgs_contention = run_check('bgs-contention', BgsCheck)
        vbms = run_check('vbms', VbmsCheck)
        OkComputer.make_optional %w[vbms bgs-vet_record bgs-corporate_update bgs-contention]

        render json: {
          mpi: mpi, vbms: vbms, evss: evss, 'bgs-claimant': bgs_claimant,
          'bgs-contention': bgs_contention, 'bgs-corporate_update': bgs_corporate_update,
          'bgs-intent_to_file': bgs_intent_to_file, 'bgs-vet_record': bgs_vet_record
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
