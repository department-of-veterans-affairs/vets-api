# frozen_string_literal: true

module Console1984
  class Supervisor
    private

    def handle_empty_username
      if Console1984.config.ask_for_username_if_empty
        ask_for_value 'Please, enter your VA email'
      else
        raise Console1984::Errors::MissingUsername
      end
    end
  end
end
