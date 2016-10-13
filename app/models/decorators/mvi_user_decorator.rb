# frozen_string_literal: true
require 'common/exceptions'
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
    # in most cases (other than ids) the user attributes from the identity provider are more up-to-date
    # but stashing the MVI data if it's needed for confirmation
    @user.attributes = {
      edipi: response[:edipi],
      icn: response[:icn],
      participant_id: response[:vba_corp_id],
      mhv_id: response[:mhv_id],
      mvi: response
    }
    @user
  rescue MVI::RecordNotFound => e
    # TODO(AJD): add cloud watch metric
    Rails.logger.error "MVI record not found for user: #{@user.uuid}"
    raise Common::Exceptions::RecordNotFound, "User not in found MVI: #{e.message}"
  rescue MVI::ServiceError => e
    # TODO(AJD): add cloud watch metric
    Rails.logger.error "Error: #{e.message} when retrieving MVI data for user: #{@user.uuid}"
    raise Common::Exceptions::InternalServerError, e
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
