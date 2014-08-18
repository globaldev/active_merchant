require_relative '../../test_helper'

class RemoteAxcessmsTest < Test::Unit::TestCase

  SUCCESS_MESSAGES = {
    "CONNECTOR_TEST" => "Successful Processing - Request successfully processed in 'Merchant in Connector Test Mode'",
    "INTEGRATOR_TEST" => "Successful Processing - Request successfully processed in 'Merchant in Integrator Test Mode'",
  }

  def setup
    @gateway = AxcessmsGateway.new(fixtures(:axcessms))

    @amount = 150
    @credit_card = credit_card("4200000000000000", month: 05, year: 2022)
    @declined_card = credit_card("4444444444444444", month: 05, year: 2022)
    @mode = "INTEGRATOR_TEST"
    @options["TRANSACTION.MODE"] = @mode
    @options["PRESENTATION.USAGE"] = "Order Number #{Time.now.to_f.divmod(2473)[1]}"
    @options[:address] = {
      :street => "Leopoldstr. 1",
      :zip => "80798",
      :city => "Munich",
      :state => "BY",
      :country => "DE",
    }
  end

  def test_successful_void
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-authorize"
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal SUCCESS_MESSAGES[@mode], auth.message

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-void"
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal SUCCESS_MESSAGES[@mode], void.message
  end

  def test_successful_authorize_and_capture
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-authorize"
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth, "authorization fails"
    assert_equal SUCCESS_MESSAGES[@mode], auth.message

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-capture"
    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture, "capture fails"
    assert_equal SUCCESS_MESSAGES[@mode], capture.message
  end

  def test_failed_refund
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-purchaze"
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal SUCCESS_MESSAGES[@mode], purchase.message

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-refund"
    purchase.authorization["IDENTIFICATION.UNIQUEID"] += "a1"
    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_failure refund
  end

  def test_failed_bigger_capture_then_authorised
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-authorize"
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-capture"
    assert capture = @gateway.capture(@amount+30, auth.authorization)
    assert_failure capture
  end

  def test_failed_authorize
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-authorize"
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-purchase"
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal SUCCESS_MESSAGES[@mode], purchase.message

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-refund"
    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund
    assert_equal SUCCESS_MESSAGES[@mode], refund.message
  end

  def test_successful_partial_refund
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-purchase"
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal SUCCESS_MESSAGES[@mode], purchase.message

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-refund"
    assert refund = @gateway.refund(@amount-50, purchase.authorization)
    assert_success refund
    assert_equal SUCCESS_MESSAGES[@mode], refund.message
  end

  def test_successful_purchase
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-purchase"
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal SUCCESS_MESSAGES[@mode], response.message
  end

  def test_successful_partial_capture
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-authorize"
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal SUCCESS_MESSAGES[@mode], auth.message

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-capture"
    assert capture = @gateway.capture(@amount-30, auth.authorization)
    assert_success capture
    assert_equal SUCCESS_MESSAGES[@mode], capture.message
  end

  def test_failed_capture
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-capture"
    response = @gateway.capture(nil, "")
    assert_failure response
  end

  def test_failed_capture_wrong_refid
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-authorize"
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-capture"
    auth.authorization["IDENTIFICATION.UNIQUEID"] += "a"
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_failure capture
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
  end

  def test_failed_purchase
    @options["IDENTIFICATION.TRANSACTIONID"] = "RubyRT #{__method__.to_s}-purchase"
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_invalid_login
    credentials = fixtures(:axcessms).merge(password: "invalid")
    response = AxcessmsGateway.new(credentials).purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
