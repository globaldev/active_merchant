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
        if payment.respond_to?(:number)
          options[:credit_card] = payment
        else
          options[:authorization] = payment
        end
        commit("CC.DB", money, options)
      end

      def authorize(money, payment, options={})
        if payment.respond_to?(:number)
          options[:credit_card] = payment
        else
          options[:authorization] = payment
        end
        commit("CC.PA", money, options)
      end

      def capture(money, authorization, options={})
        options[:authorization] = authorization
        commit("CC.CP", money, options)
      end

      def refund(money, authorization, options={})
        options[:authorization] = authorization
        commit("CC.RF", money, options)
      end

      def void(authorization, options={})
        options[:authorization] = authorization
        commit("CC.RV", nil, options)
      end

      private

      def commit(paymentcode, money, options)
        request = build_request(paymentcode, money, options)
        headers = {
          "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
          "Accept-Encoding" => "identity;q=0;"
        }

        raw_response = ssl_post((test? ? test_url : live_url), post_data(request), headers)

        parsed = Hash[CGI.unescape(raw_response).scan(/([^=]+)=([^&]+)[&$]/)]

        Response.new(success?(parsed), response_message(parsed), parsed,
          :authorization => parsed["IDENTIFICATION.UNIQUEID"],
          :test => test?
        )
      end

      def build_request(paymentcode, money, options)
        post = {}
        post["PAYMENT.CODE"] = paymentcode
        add_authentication(post)
        add_transaction(post, options)
        if options[:authorization]
          add_authorization(money, post, options)
        else
          requires!(options, :credit_card)
          add_account(post, options)
          add_payment(money, post, options)
          add_customer_data(post, options)
          add_address(post, options)
        end
        add_contact(post, options)
        add_memo(post, options)

        post
      end

      def add_authentication(post)
        post["SECURITY.SENDER"] = options[:sender]
        post["USER.LOGIN"] = options[:login]
        post["USER.PWD"] = options[:password]
        post["TRANSACTION.CHANNEL"] = options[:channel]
      end

      def add_transaction(post, options)
        post["TRANSACTION.MODE"] = options[:transaction_mode] || "INTEGRATOR_TEST"
        post["TRANSACTION.RESPONSE"] = "SYNC"
      end

      def add_authorization(money, post, options)
        post["PRESENTATION.AMOUNT"] = amount(money)
        post["PRESENTATION.CURRENCY"] = options[:currency] || currency(money)
        post["IDENTIFICATION.TRANSACTIONID"] = options[:order_id]
        post["IDENTIFICATION.REFERENCEID"] = options[:authorization]
        post["IDENTIFICATION.UNIQUEID"] = nil
        post["IDENTIFICATION.SHORTID"] = nil
      end

      def add_account(post, options)
        post["ACCOUNT.HOLDER"] = "#{options[:credit_card].first_name} #{options[:credit_card].last_name}"
        post["ACCOUNT.NUMBER"] = options[:credit_card].number
        post["ACCOUNT.EXPIRY_MONTH"] = format(options[:credit_card].month, :two_digit)
        post["ACCOUNT.EXPIRY_YEAR"] = format(options[:credit_card].year, :four_digit)
        post["ACCOUNT.VERIFICATION"] = options[:credit_card].verification_value
      end

      def add_payment(money, post, options)
        post["PRESENTATION.AMOUNT"] = amount(money)
        post["PRESENTATION.CURRENCY"] = options[:currency] || currency(money)
        post["PRESENTATION.USAGE"] = options[:soft_descriptor]
      end

      def add_customer_data(post, options)
        post["NAME.GIVEN"] = options[:credit_card].first_name
        post["NAME.FAMILY"] = options[:credit_card].last_name
      end

      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        if !address.nil?
          post["ADDRESS.STREET"] = address.values_at(:address1, :address2).reject(&:blank?).join(" ")
          post["ADDRESS.ZIP"] = address[:zip]
          post["ADDRESS.CITY"] = address[:city]
          post["ADDRESS.STATE"] = address[:state]
          post["ADDRESS.COUNTRY"]= address[:country]
        end
      end

      def add_contact(post, options)
        post["CONTACT.EMAIL"] = options[:email]
        post["CONTACT.IP"] = options[:ip]
      end

      def add_memo(post, options)
        post["PAYMENT.MEMO"] = options[:description]
      end

      def success?(response)
        response["PROCESSING.RETURN.CODE"] != nil ? response["PROCESSING.RETURN.CODE"][0..2] =="000" : false
      end

      def response_message(parsed_response)
        parsed_response["PROCESSING.REASON"].nil? ?
          parsed_response["PROCESSING.RETURN"] :
          parsed_response["PROCESSING.REASON"]  + " - " + parsed_response["PROCESSING.RETURN"]
      end

      def post_data(params)
        return nil unless params

        no_blanks = params.reject { |key, value| value.blank? }
        no_blanks.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

    end
  end
end
