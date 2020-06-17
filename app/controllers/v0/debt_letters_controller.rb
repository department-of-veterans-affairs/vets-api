# frozen_string_literal: true

module V0
  class DebtLettersController < ApplicationController
    def index
      render(json: service.list_letters)
    end

    def show
    end

    private

    def service
      @service ||= Debts::LetterDownloader.new(@current_user.ssn)
    end
  end
end
