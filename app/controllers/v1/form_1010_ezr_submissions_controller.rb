

module V1
  class Form1010EzrSubmissionsController < ApplicationController
    FORM_ID = '1010ezr'

    def create
      begin
        result = Form1010EzrSubmission::Service.new(user_identifier).submit_form(form)
      rescue HCA::SOAPParser::ValidationError
        raise Common::Exceptions::BackendServiceException.new('1010EZR422', status: 422)
      end

      clear_saved_form(FORM_ID)

      render(json: result)
    end
  end
end
