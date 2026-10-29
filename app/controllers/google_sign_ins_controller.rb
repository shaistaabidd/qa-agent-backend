# The browser's two stops on the API during Sign in with Google: start, which
# sends it to Google, and Google's callback, which sends it back to the
# frontend. Both always redirect; failures travel to the frontend too.
class GoogleSignInsController < ApplicationController
  def new
    redirect_to ::Auth::StartGoogleSignIn.call(nonce: params[:nonce]).value, allow_other_host: true
  end

  def callback
    result = ::Auth::CompleteGoogleSignIn.call(state: params[:state], code: params[:code], error: params[:error])
    redirect_to result.value, allow_other_host: true
  end
end
