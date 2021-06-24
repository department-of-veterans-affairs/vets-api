# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions'

class AppealsApi::V1::DecisionReviews::LegacyAppealsController < AppealsApi::ApplicationController
  SSN_REGEX = /^[0-9]{9}$/.freeze

  skip_before_action(:authenticate)
  before_action :validate_headers, only: %i[index]

  EXPECTED_HEADERS = %w[X-VA-SSN X-VA-File-Number].freeze

  def index
    get_legacy_appeals_from_caseflow
  end

  private

  attr_reader :caseflow_response

  def get_legacy_appeals_from_caseflow
    @caseflow_response = Caseflow::Service.new.get_legacy_appeals headers: headers
  end

  def headers
    EXPECTED_HEADERS.reduce({}) do |hash, key|
      hash.merge(key => request.headers[key])
    end.compact
  end

  def validate_headers
    validation_errors = []
    ssn = request.headers['X-VA-SSN']
    file_number = request.headers['X-VA-File-Number']

    if ssn.nil? && file_number.nil?
      validation_errors << { status: 422, detail: 'X-VA-SSN or X-VA-File-Number is required' }
    end

    if ssn.present? && !SSN_REGEX.match?(ssn)
      validation_errors << { status: 422, detail: "X-VA-SSN has an invalid format. Pattern: #{SSN_REGEX.inspect}" }
    end

    render_validation_errors(validation_errors)
  end

  def render_validation_errors(validation_errors)
    return if validation_errors.empty?

    render json: { errors: validation_errors }, status: :unprocessable_entity unless validation_errors.empty?
  end

  def render_unusable_response_error
    render json: { error: {title: 'Bad Gateway', detail: I18n.t('appeals_api.errors.caseflow_bad_gateway'), status: 502} }
  end
end
