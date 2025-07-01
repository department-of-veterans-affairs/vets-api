# frozen_string_literal: true

module SimpleFormsApi
  class VsiFlashService
    VSI_FLASH_NAME = 'VSI'

    def initialize(form_data)
      @form_data = form_data
    end

    def add_flash_to_bgs
      ssn = @form_data.dig('veteran_id', 'ssn')
      return false unless ssn

      # Add VSI flash to veteran's BGS record
      service = BGS::Services.new(external_uid: ssn, external_key: ssn)
      service.claimant.add_flash(file_number: ssn, flash_name: VSI_FLASH_NAME)

      # Confirm flash was added
      confirm_flash_addition(service, ssn)

      Rails.logger.info(
        'BGS VSI flash added successfully',
        { flash_name: VSI_FLASH_NAME, form_id: '20-10207' }
      )
      true
    rescue => e
      Rails.logger.error(
        'Simple Forms API - Failed to Add VSI Flash',
        { error: e.message, form_id: '20-10207' }
      )
      raise e
    end

    private

    def confirm_flash_addition(service, ssn)
      assigned_flashes = service.claimant.find_assigned_flashes(ssn)[:flashes]
      assigned_flash = assigned_flashes.find { |af| af[:flash_name].strip == VSI_FLASH_NAME }

      if assigned_flash.blank?
        Rails.logger.error(
          'Simple Forms API - Failed to Confirm VSI Flash Addition',
          { form_id: '20-10207' }
        )
      end
    end
  end
end
