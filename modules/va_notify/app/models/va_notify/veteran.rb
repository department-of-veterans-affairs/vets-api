# frozen_string_literal: true

module VANotify
  class Veteran
    def initialize(in_progress_form)
      @in_progress_form = in_progress_form
    end

    def icn
      @icn ||= in_progress_form&.user_account&.icn
    end

    def first_name
      @first_name ||= case in_progress_form.form_id
                      when '686C-674'
                        InProgressForm686c.new(in_progress_form.form_data).first_name
                      when '1010ez'
                        InProgressForm1010ez.new(in_progress_form.form_data).first_name
                      else
                        raise UnsupportedForm,
                              "Unsupported form: #{in_progress_form.form_id} - InProgressForm: #{in_progress_form.id}"
                      end
    end

    def user_uuid
      @user_uuid ||= in_progress_form.user_uuid
    end

    private

    attr_reader :in_progress_form
  end
end
