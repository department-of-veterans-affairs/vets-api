# frozen_string_literal: true
class Decorators::MviUserDecorator
  MVI_SERVICE = VetsAPI::Application.config.mvi_service

  def initialize(user)
    @user = user
  end

  def create
    raise Common::Exceptions::ValidationErrors, @user unless @user.valid?
    message = create_message
    raise Common::Exceptions::ValidationErrors, message unless message.valid?
    response = MVI_SERVICE.find_candidate(message)
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
