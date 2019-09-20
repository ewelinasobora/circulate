module Signup
  class PaymentsController < BaseController
    before_action :load_member

    def new
      @payment = Payment.new
      activate_step(:payment)
    end

    def create
      @payment = Payment.new(payment_params)
      unless @payment.valid?
        activate_step(:payment)
        render :new, status: :unprocessable_entity
        return
      end

      result = checkout.checkout_url(amount: @payment.amount, email: @member.email, return_to: callback_signup_payments_url, member_id: @member.id)
      if result.success?
        redirect_to result.value
      else
        flash[:error] = result.error
        redirect_to new_signup_payment_url
      end
    end

    def skip
      # completing in person
      MemberMailer.with(member: @member).welcome_message.deliver_later
      reset_session
      redirect_to signup_confirmation_url
    end

    def callback
      transaction_id = params[:transactionId]
      result = checkout.fetch_transaction(member: @member, transaction_id: transaction_id)

      if result.success?
        amount = result.value
        membership = Membership.create_for_member(@member, amount, square_transaction_id: transaction_id)

        MemberMailer.with(member: @member, amount: amount.cents).welcome_message.deliver_later

        reset_session
        session[:amount] = amount.cents

        redirect_to signup_confirmation_url
      else
        Rails.logger.error result.error
        Raven.capture_message(result.error.inspect)
        flash[:error] = "Your payment could not be processed. Please come into the library to complete signup."
        redirect_to :new
      end
    end

    private

    def payment_params
      params.require(:signup_payment).permit(:amount_dollars)
    end

    def checkout
      SquareCheckout.new(
        access_token: ENV.fetch("SQUARE_ACCESS_TOKEN"),
        location_id: ENV.fetch("SQUARE_LOCATION_ID")
      )
    end
  end
end
