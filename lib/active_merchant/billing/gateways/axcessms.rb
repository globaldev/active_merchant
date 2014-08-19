module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AxcessmsGateway < Gateway
      self.test_url = "https://test.ctpe.net/frontend/payment.prc"
      self.live_url = "https://ctpe.net/frontend/payment.prc"

      self.supported_countries = %w(AD AT BE BG BR CA CH CY CZ DE DK EE ES FI FO FR GB
                                    GI GR HR HU IE IL IM IS IT LI LT LU LV MC MT MX NL
                                    NO PL PT RO RU SE SI SK TR US VA)

      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :solo]

      self.homepage_url = "http://www.axcessms.com/"
      self.display_name = "Axcessms Gateway"
      self.money_format = :dollars
      self.default_currency = "EUR"

      def initialize(options={})
        requires!(options, :sender, :login, :password, :channel)
        super
      end

      def purchase(money, payment, options={})
        paymentcode = payment.respond_to?(:number) ? "CC.DB" : "CC.RB"
        commit(paymentcode, money, payment, options)
      end

      def authorize(money, authorization, options={})
        commit("CC.PA", money, authorization, options)
      end

      def capture(money, authorization, options={})
        commit("CC.CP", money, authorization, options)
      end

      def refund(money, authorization, options={})
        commit("CC.RF", money, authorization, options)
      end

      def void(authorization, options={})
        commit("CC.RV", nil, authorization, options)
      end

      private

      def commit(paymentcode, money, payment, options)
        request = build_request(paymentcode, money, payment, options)
        headers = {
          "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
          "Accept-Encoding" => "identity;q=0;"
        }

        response = parse(ssl_post(test? ? test_url : live_url, request.to_post_data, headers))

        Response.new(success?(response), response_message(response), response,
          :authorization => response["IDENTIFICATION.UNIQUEID"],
          :test => (response["TRANSACTION.MODE"] != "LIVE")
        )
      end

      def build_request(paymentcode, money, payment, options)
        post = PostData.new
        post["PAYMENT.CODE"] = paymentcode
        add_authentication(post)
        add_transaction(post, options)

        add_presentation(money, post, options)
        add_payment(post, payment)
        add_memo(post, options)

        if payment.respond_to?(:number)
          add_customer_data(post, payment, options)
          add_address(post, options)
        end

        post
      end

      def add_authentication(post)
        post["SECURITY.SENDER"] = options[:sender]
        post["USER.LOGIN"] = options[:login]
        post["USER.PWD"] = options[:password]
        post["TRANSACTION.CHANNEL"] = options[:channel]
      end

      def add_transaction(post, options)
        post["TRANSACTION.MODE"] = options[:transaction_mode] || (test? ? "INTEGRATOR_TEST" : "LIVE")
        post["TRANSACTION.RESPONSE"] = "SYNC"
      end

      def add_presentation(money, post, options)
        post["PRESENTATION.AMOUNT"] = amount(money)
        post["PRESENTATION.CURRENCY"] = options[:currency] || currency(money)
        post["PRESENTATION.USAGE"] = options[:soft_descriptor]
        post["IDENTIFICATION.TRANSACTIONID"] = options[:transaction_id] || generate_unique_id
        post["IDENTIFICATION.INVOICEID"] = options[:order_id]
        post["IDENTIFICATION.SHOPPERID"] = options[:customer]
        post["IDENTIFICATION.BULKID"] = options[:bulk_id]
      end

      def add_payment(post, payment)
        if payment.respond_to?(:number)
          post["ACCOUNT.HOLDER"] = payment.name
          post["ACCOUNT.NUMBER"] = payment.number
          post["ACCOUNT.EXPIRY_MONTH"] = format(payment.month, :two_digit)
          post["ACCOUNT.EXPIRY_YEAR"] = format(payment.year, :four_digit)
          post["ACCOUNT.VERIFICATION"] = payment.verification_value
        else
          post["IDENTIFICATION.REFERENCEID"] = payment
        end
      end

      def add_customer_data(post, payment, options)
        post["CONTACT.EMAIL"] = options[:email]
        post["CONTACT.IP"] = options[:ip]
        post["NAME.GIVEN"] = payment.first_name
        post["NAME.FAMILY"] = payment.last_name
      end

      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        if !address.nil?
          post["ADDRESS.STREET"] = "#{address[:address1]} #{address[:address2]}".strip
          post["ADDRESS.ZIP"] = address[:zip]
          post["ADDRESS.CITY"] = address[:city]
          post["ADDRESS.STATE"] = address[:state]
          post["ADDRESS.COUNTRY"] = address[:country]
        end
      end

      def add_memo(post, options)
        post["PAYMENT.MEMO"] = options[:description]
      end

      def success?(response)
        response["PROCESSING.RESULT"] == "ACK"
      end

      def response_message(response)
        "#{response["PROCESSING.REASON"]} - #{response["PROCESSING.RETURN"]}"
      end

      def parse(raw_response)
        Hash[
          raw_response.split('&').map do |kvp|
            kvp.split('=').map{|value| CGI.unescape(value) }
          end
        ]
      end
    end
  end
end
