# frozen_string_literal: true

module Swagger
  module Requests
    class Sessions
      include Swagger::Blocks

      swagger_path '/v0/sessions/{type}/new' do
        operation :get do
          key :description, 'Redirects to an auth service URL based on the type in params.'
          key :operationId, 'getSessionsNew'
          key :tags, %w[authentication]

          parameter do
            key :name, :type
            key :description, 'Type of auth (signup mhv dslogon idme mfa verify slo ssoe_slo)'
            key :in, :path
            key :type, :string
            key :required, true
          end

          response 200 do
            key :description, 'Response is OK'

            schema do
              property :url, type: :string, example: "https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=fVLLjtswDPwV33Sy5VdQV4gDBAkKBNg%2BkHR76GXByHQirCy5opymf18pj0UO7d4EamY4HHJOMOhRLCd%2FNFv8NSH5ZEmEzitrVtbQNKDboTspic%2Fbp5YdvR8F59pK0EdLXlR5nnMIfB6leCjrPchXlqyDljIQha40CjwYVaa6ATXsKZN2uJJ2yhw07tTBfDW3ZizZrFv20vSlbOqmT4uilmm9LyFtukqm3axqZj32XV%2FVAUo04caQB%2BNbVubFx7Qo03z2vSzF7IOoq58s%2BYGOLlbKLGfJedCGRGzesskZYYEUCQMDkvBS7Jafn0QACrhn8UgZ3%2BeMznorrWaLeUSLizu3iO%2FUjdkJPR3sKXuLcM4fYfPrRr4E2c36m9VK%2FkmWWtvfK4fgsWXeTSGdT9YN4N83EiuqS%2FsLVIwxAPJoPOP3LreVY3c5gLBvj2efrOwwglMU08IzSH%2Bf5BG10iGbLfaL20WErYKBAw6hQRbm44Z4QEwOjMRwL8ALHke%2FTftPqevff2y9%2FT4e6%2BIv&amp;RelayState=%7B%22originating_request_id%22%3A%22ffbf6f75-4363-4768-ab47-4aa1e9744e96%22%2C%22type%22%3A%22idme%22%7D&amp;SigAlg=http%3A%2F%2Fwww.w3.org%2F2000%2F09%2Fxmldsig%23rsa-sha1&amp;Signature=aPLL%2Bx566zUgklnRaLhZG2%2FASiFV7XOlbOub70weY%2FfJ3M4xLwm%2B0pLDfexD7eyTDKveWenzLi1jAIM99n8IVXtYK%2FtYE5%2BkFdaAzI5vP5%2BnEdn0qiScN4eZjn5qk9Bo0eRNAOwC1XjuBwENmu3SlBVjUVwpRTDfqHvFk53zIbzUILqPj7bQ0EGxrPAesG411ONUJX9K1hQcW5LWNj2l3QVMc%2FfYaPsCIlAOebJ8nvD%2F5F%2BTQc%2B6OutcgnqXzGq0ok%2FxkGW61SQ8SbDi45PllOPKCwzPr%2BsD%2Bjn27mBv%2FaRqTVliPy3wPXTlgEfhReGcTz3Vl9g4mxECiJU9H7rpzQ%3D%3D"
            end
          end
        end
      end
    end
  end
end
