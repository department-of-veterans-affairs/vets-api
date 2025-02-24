module DebtsApi
  class V0::OneDebtLetterService
    def initialize(user)
      @user = user
    end

    def get_pdf
      copays = vbs_service.get_copays
      debts = dmc_service.get_debts

      Prawn::Document.new(page_size: 'LETTER').render

    end

    def vbs_service
      MedicalCopays::VBS::Service.build(user: current_user)
    end

    def dmc_service
      DebtManagementCenter::DebtsService.new(current_user)
    end
  end
end
