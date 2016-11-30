module HCA
  module EnrollmentSystem
    module_function

    FORM_TEMPLATE = {
      form: {
        formIdentifier: {
          type: '100',
          value: '1010EZ',
          version: 1986360435
        }
      },
      identity: {
        authenticationLevel: {
          type: '100',
          value: 'anonymous'
        }
      }
    }

    def has_financial_flag(veteran)
      veteran[:understandsFinancialDisclosure] || veteran[:discloseFinancialInformation]
    end

    def transform(data)
    end
  end
end
