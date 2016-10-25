# frozen_string_literal: true
module Common
  module Exceptions
    module MinorCodes
      VALIDATION_ERRORS = {
        type: :resource,
        code: '100',
        status: MajorCodes::UNPROCESSABLE_ENTITY
      }.freeze

      CLIENT_ERROR = {
        type: :client,
        code: '900',
        status: MajorCodes::BAD_REQUEST,
        title: 'Operation failed'
      }.freeze

      INVALID_RESOURCE = {
        type: :resource,
        code: '101',
        status: MajorCodes::BAD_REQUEST,
        title: 'Invalid resource'
      }.freeze

      INVALID_FIELD = {
        type: :collection,
        code: '102',
        status: MajorCodes::BAD_REQUEST,
        title: 'Invalid field'
      }.freeze

      INVALID_FIELD_VALUE = {
        type: :collection,
        code: '103',
        status: MajorCodes::BAD_REQUEST,
        title: 'Invalid field value'
      }.freeze

      FILTER_NOT_ALLOWED = {
        type: :collection,
        code: '104',
        status: MajorCodes::BAD_REQUEST,
        title: 'Filter not allowed'
      }.freeze

      INVALID_FILTERS_SYNTAX = {
        type: :collection,
        code: '105',
        status: MajorCodes::BAD_REQUEST,
        title: 'Invalid filters syntax'
      }.freeze

      INVALID_SORT_CRITERIA = {
        type: :collection,
        code: '106',
        status: MajorCodes::BAD_REQUEST,
        title: 'Invalid sort criteria'
      }.freeze

      INVALID_PAGINATION_PARAMS = {
        type: :collection,
        code: '107',
        status: MajorCodes::BAD_REQUEST,
        title: 'Invalid pagination params'
      }.freeze

      PARAMETER_MISSING = {
        type: :custom,
        code: '108',
        status: MajorCodes::BAD_REQUEST,
        title: 'Missing Parameter'
      }.freeze

      UNAUTHORIZED = {
        type: :custom,
        code: '401',
        status: MajorCodes::UNAUTHORIZED,
        title: 'Not Authorized',
        detail: 'Not Authorized'
      }.freeze

      # Deliberately not implementing this one, because RECORD_NOT_FOUND
      # should be used instead.
      FORBIDDEN = {
        type: :custom,
        code: '403',
        status: MajorCodes::FORBIDDEN
      }.freeze

      RECORD_NOT_FOUND = {
        type: :id,
        code: '404',
        status: MajorCodes::RECORD_NOT_FOUND,
        title: 'Record not found'
      }.freeze

      INTERNAL_SERVER_ERROR = {
        type: :other,
        code: '500',
        status: MajorCodes::SERVER_ERROR,
        title: 'Internal Server Error',
        detail: 'Internal Server Error'
      }.freeze

      SERVICE_OUTAGE = {
        type: :other,
        code: '503',
        status: MajorCodes::SERVICE_OUTAGE,
        title: 'Backend Service Outage',
        detail: 'Backend Service Outage'
      }.freeze
    end
  end
end
