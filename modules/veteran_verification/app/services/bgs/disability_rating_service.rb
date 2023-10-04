# frozen_string_literal: true

module BGS
  class DisabilityRatingService
    def get_rating(current_user)
      service = BGS::Services.new(
        external_uid: current_user.icn,
        external_key: current_user.email
      )
      begin
        service.rating.find_rating_data(current_user.ssn)
      rescue => e
        if e.message.include? 'PERSON_NOT_FOUND'
          handle_not_found_error!
        else
          throw e
        end
      end
    end

    def handle_not_found_error!
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'Person Not Found.')
    end
  end
end
