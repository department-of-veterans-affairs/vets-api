# frozen_string_literal: true

module V0
  class NoticeOfDisagreementsController < AppealsBaseController
    private

    def error_class(method:, exception_class:)
      "#{self.class.name}##{method} exception #{exception_class} (NOD)"
    end
  end
end
