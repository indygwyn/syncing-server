class Api::SessionsController < Api::ApiController
  respond_to :json

  before_action do
    if current_session.nil?
      render_unsupported_account_version
    end
  end

  def active_sessions
    sessions = current_user.active_sessions
    sessions.each { |session| session[:current] = current_session.uuid == session['uuid'] }

    render json: { active_sessions: sessions }
  end

  def delete
    unless params[:uuid]
      render json: { error: { message: 'Please provide the session UUID.' } }, status: :bad_request
      return
    end

    if params[:uuid] == current_session.uuid
      render json: { error: { message: 'You can not delete your current session.' } }, status: :bad_request
      return
    end

    session = current_user.sessions.where(uuid: params[:uuid]).first

    unless session
      render json: { error: { message: 'No session exist with the provided UUID.' } }, status: :bad_request
      return
    end

    session.destroy

    render json: {}, status: :no_content
  end

  def delete_all
    current_user.sessions.where.not(uuid: current_session.uuid).destroy_all
    render json: {}, status: :no_content
  end

  def refresh
    unless params[:refresh_token]
      render json: {
        error: {
          message: 'Please provide the refresh token.',
        },
      }, status: :bad_request
      return
    end

    session = current_user.sessions.where('refresh_token = ?', params[:refresh_token]).first

    unless session
      render json: {
        error: {
          tag: 'invalid-refresh-token',
          message: 'The refresh token is not valid.',
        },
      }, status: :bad_request
      return
    end

    unless session.regenerate_tokens
      render json: {
        error: {
          tag: 'expired-refresh-token',
          message: 'The refresh token is expired.',
        },
      }, status: :bad_request
      return
    end

    render json: {
      access_token: session.access_token,
      expire_at: session.access_token_expire_at,
      refresh_token: session.refresh_token,
    }
  end

  private

  def render_unsupported_account_version
    render json: {
      error: {
        tag: 'unsupported-account-version',
        message: 'Account version not supported.',
      },
    }, status: :bad_request
  end
end