# frozen_string_literal: true
require 'mvi/service_factory'

class Decorators::MviUserDecorator
  def initialize(user)
    @user = user
    @mvi_service = MVI::ServiceFactory.get_service(mock_service: ENV['MOCK_MVI_SERVICE'])
  end

  def create
    raise Common::Exceptions::ValidationErrors, @user unless @user.valid?
    message = create_message
    response = @mvi_service.find_candidate(message)
    @user.attributes = { mvi: response }
    @user
  rescue MVI::ServiceError => e
    # TODO(AJD): add cloud watch metric
    Rails.logger.error "MVI user data not retrieved: service error: #{e.message} for user: #{@user.uuid}"
    raise Common::Exceptions::RecordNotFound, "Failed to retrieve MVI data: #{e.message}"
  end

  def create_message
    given_names = [@user.first_name]
    given_names.push @user.middle_name unless @user.middle_name.nil?
    MVI::Messages::FindCandidateMessage.new(
      given_names,
      @user.last_name,
      @user.birth_date,
      @user.ssn,
      @user.gender
    )
  end
end
