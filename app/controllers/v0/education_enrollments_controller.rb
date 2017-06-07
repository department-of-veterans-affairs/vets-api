# frozen_string_literal: true
module V0
  class EducationEnrollmentsController < ApplicationController
    def show
      # TODO: fetch for realz
      ee = FactoryGirl.build(:education_enrollment)
      render json: ee
    end
  end
end
