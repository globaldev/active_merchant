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
      self.default_currency = "GBP"

      API_VERSION = "1.0"
      PAYMENT_CODE_PREAUTHORIZATION = "CC.PA"
      PAYMENT_CODE_DEBIT = "CC.DB"
      PAYMENT_CODE_CAPTURE = "CC.CP"
      PAYMENT_CODE_REVERSAL = "CC.RV"
      PAYMENT_CODE_REFUND = "CC.RF"
      PAYMENT_CODE_REBILL = "CC.RB"


      def initialize(options={})
        requires!(options, :sender, :login, :password, :channel)
        super
      end

      def purchase(money, payment, options={})
        payment_code = payment.respond_to?(:number) ? PAYMENT_CODE_DEBIT : PAYMENT_CODE_REBILL
        commit(payment_code, money, payment, options)
      end

      def authorize(money, authorization, options={})
        commit(PAYMENT_CODE_PREAUTHORIZATION, money, authorization, options)
      end

      def capture(money, authorization, options={})
        commit(PAYMENT_CODE_CAPTURE, money, authorization, options)
      end

      def refund(money, authorization, options={})
        commit(PAYMENT_CODE_REFUND, money, authorization, options)
      end

      def void(authorization, options={})
        commit(PAYMENT_CODE_REVERSAL, nil, authorization, options)
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

      def build_request(payment_code, money, payment, options)
        post = PostData.new

        post["REQUEST.VERSION"] = API_VERSION
        post["PAYMENT.CODE"] = payment_code

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
        post["TRANSACTION.MODE"] = options[:transaction_mode] || (test? ? "CONNECTOR_TEST" : "LIVE")
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
          post["ACCOUNT.BRAND"] = payment.brand
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
          post["NAME.COMPANY"] = address[:company]
          post["CONTACT.PHONE"] = address[:phone]
          post["CONTACT.MOBILE"] = address[:mobile_phone]
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
          raw_response.strip.split('&').map do |kvp|
            kvp.split('=').map{|value| CGI.unescape(value) }
          end
        ]
      end
    end
  end
end
