class AdminController < ApplicationController
  layout 'admin_bootstrap'

  before_action :require_user
  helper_method :current_user_session, :current_user

  private

  def set_stamper
    User.stamper ||= current_user
  end

  def store_location(url = request.url)
    session[:return_to] = url
  end

  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  def require_user
    unless current_user
      if request.xhr?
        store_location(request.referer)
        render body: nil, status: 403
        flash[:error] = 'Your session expired, please sign in again to continue.'
        return false
      else
        store_location
        if current_user_session && current_user_session.stale?
          flash[:error] = "Your session has expired; please log in again."
        else
          flash[:error] = "You must be logged in to access that page."
        end
        redirect_to admin_login_url
        return false
      end
    end
  end

  def require_no_user
    if current_user
      redirect_back_or_default admin_home_url
      return false
    end
  end
end
