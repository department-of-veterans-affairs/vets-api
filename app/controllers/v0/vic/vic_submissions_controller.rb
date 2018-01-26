# frozen_string_literal: true

module V0
  module VIC
    class VICSubmissionsController < ApplicationController
      skip_before_action(:authenticate)

      def create
        vic_submission = ::VIC::VICSubmission.create!
      end
    end
  end
end
