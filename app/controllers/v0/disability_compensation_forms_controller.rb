# frozen_string_literal: true

module V0
  class DisabilityCompensationFormsController < ApplicationController
    before_action { authorize :evss, :access? }

    def rated_disabilities
      response = service.get_rated_disabilities
      render json: response,
             serializer: RatedDisabilitiesSerializer
    end

    def submit
      form = JSON.parse(request.body.string)
      veteran_info = form['form526']['veteran']
      form['form526']['veteran']['mailingAddress'] = transform_address(veteran_info['mailingAddress'])
      form['form526']['veteran']['forwardingAddress'] = transform_address(veteran_info['forwardingAddress'])

      jid = EVSS::DisabilityCompensationForm::SubmitForm.start(@current_user, form.to_json)
      Rails.logger.info('submit form start', user: @current_user.uuid, component: 'EVSS', form: '21-526EZ', jid: jid)
      head 200
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end

    # Address conversion from a common address type to PCIU address type
    def transform_address(address)
      pciu_address = { 'country' => address['country'],
                       'addressLine1' => address['addressLine1'],
                       'addressLine2' => address['addressLine2'],
                       'addressLine3' => address['addressLine3'],
                       'effectiveDate' => address['effectiveDate'] }

      pciu_address['type'] = get_address_type(address)

      case pciu_address['type']
      when 'DOMESTIC'
        pciu_address['city'] = address['city']
        pciu_address['state'] = address['state']
        pciu_address['zipFirstFive'] = address['zipCode'][0, 5]
        pciu_address['zipLastFour'] = address['zipCode'][-4..-1] if address['zipCode'].length > 5
      when 'MILITARY'
        pciu_address['militaryPostOfficeTypeCode'] = address['city']
        pciu_address['militaryStateCode'] = address['state']
      when 'INTERNATIONAL'
        pciu_address['city'] = address['city']
      end

      pciu_address.compact
    end

    def get_address_type(address)
      case address['country']
      when 'USA'
        %w[AA AE AP].include?(address['state']) ? 'MILITARY' : 'DOMESTIC'
      else
        'INTERNATIONAL'
      end
    end
  end
end
