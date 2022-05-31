class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # rescue_from Exception, with: :get_errors if Rails.env.production?

  # #Interface Only Witout CanCan
  # #rescue_from CanCan::AccessDenied, with: :access_denied

  # protect_from_forgery with: :exception

  # before_action :configure_charsets
  # # before_action :authenticate_user!

  # def configure_charsets
  #   headers["Content-Type"]="text/html;charset=utf-8"
  # end
     
  # private
  # #Interface Only Witout CanCan
  # # def access_denied exception
  # #   @error_title = I18n.t 'errors.access_deny.title', default: 'Access Denied!'
  # #   @error_message = I18n.t 'errors.access_deny.message', default: 'The user has no permission to vist this page'
  # #   render template: '/errors/error_page',layout: false
  # # end

  # def get_errors exception
  #   puts exception
  #   puts exception.backtrace
  #   Rails.logger.error(exception)

  #   @error_title = I18n.t 'errors.get_errors.title', default: 'Get An Error!'
  #   @error_message = I18n.t 'errors.get_errors.message', default: 'The operation you did get an error'
  #   render :template => '/errors/error_page',layout: false
  # end
end
